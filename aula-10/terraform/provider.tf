# provider.tf — aula-10 (Terraform GitOps + CD)
#
# Provider fixado em 5.31.0: no AWS Academy Learner Lab ha uma SCP que nega
# s3:GetBucketObjectLockConfiguration, e versoes mais novas do provider fazem
# essa leitura no refresh de recursos S3, resultando em AccessDenied.
#
# BACKEND: ficamos no backend LOCAL de proposito. O state remoto em S3 +
# DynamoDB e o certo em producao (e foi o que fiz na prova do 1o bimestre),
# mas aqui o apply roda no GitHub Actions a cada merge: um state local em
# runner efemero significa que cada execucao comeca sem state. Documentei essa
# limitacao, e o que ela custa, em gitops-cd-analise.md.

terraform {
  required_version = ">= 1.5.0"

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
