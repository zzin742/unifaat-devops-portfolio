terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ==========================================================================
  # Remote state
  # ==========================================================================
  # Por que sair do state local:
  #
  #   1. O state local vive numa maquina so. Quem mais mexer na infra trabalha
  #      as cegas, e o disco daquela maquina vira ponto unico de falha.
  #   2. O state guarda valores sensiveis em texto puro - a senha do RDS entre
  #      eles. No S3 ele fica criptografado em repouso.
  #   3. Sem lock, dois applies simultaneos escrevem por cima um do outro. A
  #      tabela do DynamoDB serializa: quem chega depois espera.
  #
  # O bloco backend NAO aceita variaveis nem interpolacao - os valores precisam
  # ser literais. O nome do bucket sai do `terraform output bloco_backend` em
  # backend/, que ja imprime este bloco pronto para colar.
  #
  # ORDEM DE EXECUCAO:
  #   1. cd backend/ && terraform apply
  #   2. colar o bucket abaixo
  #   3. cd .. && terraform init   (migra o state local para o S3)
  backend "s3" {
    bucket         = "__PREENCHER_COM_O_OUTPUT_DO_BACKEND__"
    key            = "aula-05/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "technova-tfstate-lock-3225002"
  }
}

# As credenciais vem de ~/.aws/credentials, atualizadas a cada sessao do
# Learner Lab (incluem session token e expiram em ~4h). Nada de chave fixa
# no codigo.
provider "aws" {
  region = var.aws_region
}
