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

variable "public_subnets" {
  description = "Subnets publicas: chave = sufixo do nome, valor = cidr + indice da AZ."
  type = map(object({
    cidr     = string
    az_index = number
  }))
  default = {
    "public-a" = { cidr = "10.0.1.0/24", az_index = 0 }
    "public-b" = { cidr = "10.0.3.0/24", az_index = 1 }
  }
}

variable "private_subnets" {
  description = "Subnets privadas: chave = sufixo do nome, valor = cidr + indice da AZ."
  type = map(object({
    cidr     = string
    az_index = number
  }))
  default = {
    "private-a" = { cidr = "10.0.2.0/24", az_index = 0 }
    "private-b" = { cidr = "10.0.4.0/24", az_index = 1 }
  }
}

variable "instance_type" {
  description = "Tipo da instancia. O Learner Lab limita aos tipos menores."
  type        = string
  default     = "t3.micro"
}

# No Learner Lab a key pair ja existe e chama `vockey`. A privada e baixada
# pelo painel do lab (AWS Details -> SSH key -> Download PEM), nao gerada pelo
# Terraform - por isso `tls_private_key` e `aws_key_pair` sairam desta versao.
variable "key_name" {
  description = "Nome da key pair pre-existente no Learner Lab."
  type        = string
  default     = "vockey"
}

variable "ssh_key_path" {
  description = "Caminho local do labsuser.pem baixado do painel do lab."
  type        = string
  default     = "~/.ssh/labsuser.pem"
}

variable "api_port" {
  description = "Porta em que a API Node.js escuta."
  type        = number
  default     = 3000
}

locals {
  common_tags = {
    Project     = "TechNova"
    Environment = "development"
    ManagedBy   = "Terraform"
    Owner       = var.ra
    Disciplina  = "DevOps - UniFAAT 2026-2"
    Ambiente    = "AWS Academy Learner Lab"
  }
}

data "aws_availability_zones" "disponiveis" {
  state = "available"
}
