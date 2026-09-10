# ============================================================================
# Infraestrutura de BACKEND do Terraform - S3 + DynamoDB
# ============================================================================
# Aluno: Jose Henrique Teixeira Luiz - RA 3225002
#
# Este diretorio e um problema de ovo e galinha: ele cria o bucket onde o state
# dos OUTROS projetos vai morar. Como o bucket ainda nao existe quando este
# codigo roda, este projeto usa state LOCAL. E a unica excecao consciente.
#
# Rode este diretorio PRIMEIRO, depois a raiz de aula-05/.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "Regiao AWS. O Learner Lab opera em us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "ra" {
  description = "RA do aluno."
  type        = string
  default     = "3225002"
}

locals {
  common_tags = {
    Project    = "TechNova"
    Aula       = "05"
    Owner      = var.ra
    ManagedBy  = "Terraform"
    Disciplina = "DevOps - UniFAAT 2026-2"
  }
}

# Nome de bucket S3 e global: precisa ser unico no mundo inteiro, nao so na
# conta. O sufixo aleatorio evita colisao com outro aluno da turma usando o
# mesmo prefixo.
resource "random_id" "sufixo" {
  byte_length = 4
}

resource "aws_s3_bucket" "state" {
  bucket = "technova-tfstate-${var.ra}-${random_id.sufixo.hex}"

  # O bucket guarda o state de OUTRO projeto. Um destroy acidental aqui levaria
  # junto o state da infra principal, que passaria a ser invisivel para o
  # Terraform - recursos orfaos, cobrando, sem forma limpa de remover.
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "technova-tfstate"
  })
}

# Versionamento: o state e o unico registro do que existe na AWS. Um apply
# corrompido ou um destroy indevido pode ser revertido para a versao anterior.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# O state guarda valores sensiveis em texto puro - inclusive a senha do RDS.
# Criptografia em repouso nao e opcional aqui.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueio total de acesso publico, nos quatro eixos. Um bucket de state
# exposto entrega o mapa completo da infraestrutura.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# Lock de state
# ============================================================================
# Sem lock, dois applies simultaneos escrevem o mesmo arquivo e o ultimo vence
# - o state passa a divergir da realidade. A tabela guarda um item por state
# em uso; quem chega depois espera.
#
# A partition key PRECISA se chamar LockID: o nome e fixo no protocolo do
# backend s3, nao e escolha nossa.
resource "aws_dynamodb_table" "lock" {
  name         = "technova-tfstate-lock-${var.ra}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "technova-tfstate-lock"
  })
}
