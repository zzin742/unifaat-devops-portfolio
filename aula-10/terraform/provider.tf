# provider.tf — aula-10 (Terraform GitOps + CD)
#
# Provider fixado em 5.31.0: no AWS Academy Learner Lab ha uma SCP que nega
# s3:GetBucketObjectLockConfiguration, e versoes mais novas do provider fazem
# essa leitura no refresh de recursos S3, resultando em AccessDenied.
#
# BACKEND REMOTO: obrigatorio aqui, nao opcional. O apply roda no GitHub
# Actions a cada merge, em runner efemero — com state local, cada execucao
# comecaria do zero e tentaria recriar o que ja existe (AlreadyExists). O S3
# guarda o state e a tabela DynamoDB garante o lock, impedindo que dois merges
# proximos apliquem em paralelo sobre o mesmo state.
#
# O bucket e a tabela sao criados FORA do Terraform (AWS CLI): e o problema do
# ovo e da galinha — o backend precisa existir antes do primeiro init.

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "tfstate-aula10-3225002"
    key            = "aula-10/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-aula10-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }
}

provider "aws" {
  region = var.regiao

  default_tags {
    tags = var.tags
  }
}
