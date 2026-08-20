variable "aws_region" {
  description = "Região AWS onde os recursos IAM serão gerenciados."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado na composição dos nomes e tags."
  type        = string
  default     = "technova"
}

variable "environment" {
  description = "Ambiente lógico da infraestrutura."
  type        = string
  default     = "dev"
}

variable "aluno" {
  description = "Nome completo do aluno responsável pela entrega."
  type        = string
  default     = "Jose Henrique Teixeira Luiz"
}

variable "ra" {
  description = "RA do aluno. Prefixa todos os recursos para evitar colisão na conta compartilhada."
  type        = string
  default     = "3225002"
}

variable "data_bucket_prefix" {
  description = "Prefixo dos buckets de dados da aplicação acessados pela service role."
  type        = string
  default     = "technova-app-data"
}

locals {
  # Prefixo pessoal em todo recurso: nomes de IAM são únicos por conta, e a
  # turma inteira usa a mesma. Sem isso, dois alunos colidem no apply.
  prefix = "${var.ra}-${var.project_name}"

  common_tags = {
    Project     = "TechNova"
    ManagedBy   = "Terraform"
    Aluno       = var.aluno
    RA          = var.ra
    Disciplina  = "DevOps - UniFAAT 2026-2"
    Aula        = "03"
    Environment = var.environment
  }
}
