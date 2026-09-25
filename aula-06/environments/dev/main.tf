# Composicao dos modulos da biblioteca para este ambiente.
#
# Encadeamento de outputs em inputs — e ele que faz o Terraform deduzir a ordem
# de criacao pelo grafo de dependencias, sem nenhum depends_on escrito a mao:
#
#   vpc     ──vpc_id───────────────►  api_sg
#   vpc     ──vpc_id───────────────►  rds_sg
#   api_sg  ──sg_id────────────────►  rds_sg      (libera 5432 so para a API)
#   vpc     ──public_subnet_ids[0]─►  api_server
#   api_sg  ──sg_id────────────────►  api_server
#   vpc     ──private_subnet_ids───►  database
#   rds_sg  ──sg_id────────────────►  database

# AMI por data source: um ID de AMI e regional e muda a cada release da Amazon.
# O modulo ec2 recebe o ID pronto, entao serve para qualquer imagem.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ---------- Rede ----------
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  subnets      = var.subnets
}

# ---------- Security Groups ----------
module "api_sg" {
  source = "../../modules/security-group"

  name         = "api-sg"
  description  = "SSH administrativo e porta 3000 da API da TechNova"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  ingress_rules = [
    {
      description = "SSH administrativo"
      from_port   = 22
      to_port     = 22
      cidr_blocks = var.ssh_allowed_cidrs
    },
    {
      description = "API HTTP"
      from_port   = 3000
      to_port     = 3000
      cidr_blocks = ["0.0.0.0/0"]
    },
  ]
}

module "rds_sg" {
  source = "../../modules/security-group"

  name         = "rds-sg"
  description  = "PostgreSQL acessivel apenas pela EC2 da API"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  # Nenhuma regra por CIDR: o banco nao aceita conexao de bloco de IP nenhum.
  # A origem autorizada e o SG da API — se fosse o CIDR da subnet publica,
  # qualquer recurso futuro naquela subnet ganharia acesso ao banco de graca.
  ingress_rules = [
    {
      description              = "PostgreSQL a partir do SG da API"
      from_port                = 5432
      to_port                  = 5432
      source_security_group_id = module.api_sg.sg_id
    },
  ]

  # O RDS nao inicia conexao para fora.
  enable_default_egress = false
}

# ---------- Banco de dados ----------
module "database" {
  source = "../../modules/rds"

  project_name = var.project_name
  environment  = var.environment

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.rds_sg.sg_id]
  instance_class     = var.db_instance_class
}

# ---------- Aplicacao ----------
module "api_server" {
  source = "../../modules/ec2"

  instance_name = "api"
  project_name  = var.project_name
  environment   = var.environment

  ami_id        = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.api_sg.sg_id]

  # Recursos que o Learner Lab ja fornece — o Lab nega iam:CreateRole e a
  # criacao de key pair propria.
  key_name             = "vockey"
  iam_instance_profile = "LabInstanceProfile"

  # O endpoint do RDS so e conhecido no fim do apply do banco, entao esta
  # referencia e o que garante que a EC2 suba depois dele.
  user_data = templatefile("${path.module}/../../user_data.sh.tftpl", {
    db_host     = module.database.db_host
    db_port     = module.database.db_port
    db_name     = module.database.db_name
    db_user     = var.db_username
    db_password = var.db_password
    environment = var.environment
  })
}
