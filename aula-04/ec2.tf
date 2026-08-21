# ============================================================================
# AMI — descoberta em runtime, nunca fixada
# ============================================================================
# ID de AMI muda por região e a cada release da Amazon. Fixar "ami-0abc123"
# quebra em outra região e vai ficando desatualizado (sem patches de segurança).
# O data source resolve sempre a mais recente.

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================================
# Key pair — gerada pelo Terraform
# ============================================================================
# A chave privada é gerada localmente e só a PÚBLICA vai pra AWS. A privada é
# salva em ~/.ssh com permissão 0400, fora do repositório.
#
# Ressalva honesta: a chave privada fica registrada no terraform.tfstate em
# texto puro. É justamente por isso que o .gitignore bloqueia o tfstate, e por
# que em ambiente real o state vai pra backend remoto criptografado (S3 +
# KMS), nunca em disco local.

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${var.ra}-${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-key"
  })
}

resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = pathexpand(var.ssh_key_path)
  file_permission = "0400"
}

# ============================================================================
# Instância da API
# ============================================================================
# Vai numa subnet PÚBLICA porque precisa ser alcançável pelo curl da evidência.
# Num desenho de produção, a API ficaria em subnet privada atrás de um Load
# Balancer — que é exatamente o "pronta para receber um LB no futuro" do
# enunciado, e o motivo de já existirem duas subnets públicas em AZs distintas.

resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public["public-a"].id
  vpc_security_group_ids = [aws_security_group.api.id]
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  # IMDSv2 obrigatório: bloqueia o SSRF clássico em que uma requisição forjada
  # pela aplicação lê as credenciais da role no endpoint de metadados.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-api"
  })
}
