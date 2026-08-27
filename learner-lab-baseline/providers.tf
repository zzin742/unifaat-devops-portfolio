terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# No Learner Lab as credenciais sao temporarias e incluem session token. Elas
# vem de ~/.aws/credentials, atualizadas a cada sessao do lab. Nada de chave
# fixa aqui.
provider "aws" {
  region = var.aws_region
}
