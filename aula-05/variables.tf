variable "aws_region" {
  description = "Regiao AWS. O Learner Lab opera em us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo de nome dos recursos."
  type        = string
  default     = "technova"
}

variable "ra" {
  description = "RA do aluno. Vai na tag Owner."
  type        = string
  default     = "3225002"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet publica, onde fica a EC2."
  type        = string
  default     = "10.0.1.0/24"
}

# Duas subnets privadas em AZs diferentes: exigencia do DB Subnet Group do RDS,
# que so aceita ser criado cobrindo no minimo duas zonas. Vale mesmo com
# multi_az = false - o grupo precisa das duas para permitir failover futuro.
variable "private_subnets" {
  description = "Subnets privadas do RDS: chave = nome, valor = cidr + indice da AZ."
  type = map(object({
    cidr     = string
    az_index = number
  }))
  default = {
    "private-a" = { cidr = "10.0.10.0/24", az_index = 0 }
    "private-b" = { cidr = "10.0.11.0/24", az_index = 1 }
  }
}

variable "instance_type" {
  description = "Tipo da EC2. O enunciado pede t2.micro."
  type        = string
  default     = "t2.micro"
}

# No Learner Lab a key pair ja existe e se chama `vockey`. A privada e baixada
# no painel do lab (AWS Details -> SSH key -> Download PEM). Por isso este
# projeto NAO cria key pair - diferente da aula-04.
variable "key_name" {
  description = "Key pair pre-existente no Learner Lab."
  type        = string
  default     = "vockey"
}

variable "ssh_key_path" {
  description = "Caminho local do labsuser.pem baixado do painel do lab."
  type        = string
  default     = "~/.ssh/labsuser.pem"
}

variable "api_port" {
  description = "Porta da API."
  type        = number
  default     = 3000
}

variable "meu_ip_ssh" {
  description = "CIDR autorizado a abrir SSH. Deixar 0.0.0.0/0 so em laboratorio."
  type        = string
  default     = "0.0.0.0/0"
}

# ============================================================================
# Banco de dados
# ============================================================================

variable "db_engine_version" {
  description = "Versao do PostgreSQL."
  type        = string
  default     = "15"
}

variable "db_instance_class" {
  description = "Classe da instancia RDS. Free Tier: db.t3.micro."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento em GB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nome do banco inicial."
  type        = string
  default     = "technova"
}

variable "db_username" {
  description = "Usuario master do RDS."
  type        = string
  default     = "technova_admin"

  validation {
    condition     = !contains(["admin", "postgres", "root"], lower(var.db_username))
    error_message = "Nao use nomes reservados do PostgreSQL (admin, postgres, root)."
  }
}

# A senha NAO tem default de proposito: sem valor definido, o Terraform para e
# pergunta, em vez de subir um banco com credencial previsivel. O valor real
# vai em terraform.tfvars, que esta no .gitignore.
variable "db_password" {
  description = "Senha do usuario master. Definir em terraform.tfvars (nao versionado)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "A senha do RDS precisa de pelo menos 12 caracteres."
  }
}

locals {
  common_tags = {
    Name        = "technova"
    Project     = "TechNova"
    Aula        = "05"
    Owner       = var.ra
    Environment = "development"
    ManagedBy   = "Terraform"
    Disciplina  = "DevOps - UniFAAT 2026-2"
    Ambiente    = "AWS Academy Learner Lab"
  }
}

data "aws_availability_zones" "disponiveis" {
  state = "available"
}
