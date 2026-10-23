# main.tf — aula-10: a infra que o CD precisa para existir
# =============================================================================
# Um repositorio ECR (destino do push) e uma EC2 com Docker (destino do deploy).
#
# Restricoes do Learner Lab que moldaram este arquivo:
#   - Nao e permitido criar roles/policies IAM -> usamos o LabInstanceProfile
#     pre-provisionado, em vez de criar um perfil proprio para a instancia.
#   - O par de chaves pronto chama-se 'vockey'.
#   - Regiao fixa us-east-1.
#   - Nao ha OIDC provider: o GitHub Actions autentica com as 3 credenciais
#     temporarias de sessao como secrets (ver gitops-cd-analise.md).
# =============================================================================

# Usamos a VPC default em vez de criar uma: o objetivo da aula e o pipeline,
# e cada recurso a mais e mais tempo de apply a cada merge.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# AMI mais recente do Amazon Linux 2023, resolvida no plan: fixar um id de AMI
# quebra em outra regiao e envelhece sem avisar.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# -----------------------------------------------------------------------------
# Registry: destino do push do pipeline CD.
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "api" {
  name                 = "${var.projeto}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # lab: permite destroy sem esvaziar na mao

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Guardrail de custo: imagem sem tag nao fica acumulando no registry.
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expira imagens sem tag apos 7 dias"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}

# -----------------------------------------------------------------------------
# Rede: so o que o deploy precisa — SSH para o runner e a porta da API.
# -----------------------------------------------------------------------------
resource "aws_security_group" "api" {
  name        = "${var.projeto}-sg"
  description = "SSH para o pipeline de deploy e acesso HTTP a TechNova API"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH usado pelo job de deploy do GitHub Actions"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "TechNova API"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida liberada: a instancia precisa puxar imagem do ECR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.projeto}-sg" }
}

# -----------------------------------------------------------------------------
# A instancia que recebe o deploy.
# O user_data so prepara o terreno (Docker + AWS CLI). Quem coloca a aplicacao
# no ar e o job de deploy do cd.yml, por SSH — e esse e o ponto da aula:
# infraestrutura e deploy sao dois fluxos separados.
# -----------------------------------------------------------------------------
resource "aws_instance" "api" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.api.id]
  key_name                    = var.key_name
  iam_instance_profile        = var.instance_profile
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required" # IMDSv2 obrigatorio
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    dnf update -y
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
    # O AWS CLI v2 ja vem na AL2023; o deploy usa ele para o login no ECR.
  EOF

  # Trocar o user_data recria a instancia; sem isso a mudanca ficaria so no
  # metadado e a maquina continuaria com a configuracao antiga.
  user_data_replace_on_change = true

  tags = {
    Name     = "${var.projeto}-api"
    Ambiente = var.ambiente_label
  }
}
