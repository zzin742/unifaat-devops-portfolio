variable "aws_region" {
  description = "Região AWS onde a infraestrutura sobe."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo de nome dos recursos."
  type        = string
  default     = "technova"
}

variable "ra" {
  description = "RA do aluno. Vai na tag Owner e no nome da key pair."
  type        = string
  default     = "3225002"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

# Subnets declaradas como mapa em vez de recurso repetido: adicionar uma
# terceira AZ vira uma entrada aqui, não um bloco novo de resource.
variable "public_subnets" {
  description = "Subnets públicas: chave = sufixo do nome, valor = cidr + índice da AZ."
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
  description = "Subnets privadas: chave = sufixo do nome, valor = cidr + índice da AZ."
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
  description = "Tipo da instância. Ver nota sobre t2.micro x t3.micro no README."
  type        = string
  default     = "t3.micro"

  # O enunciado pede t2.micro. Esta conta usa o plano gratuito novo da AWS
  # (créditos de 6 meses), que restringe o RunInstances aos tipos marcados como
  # free-tier-eligible — e o t2.micro não está mais nessa lista. A tentativa
  # retorna:
  #   InvalidParameterCombination: The specified instance type is not eligible
  #   for Free Tier.
  # t3.micro é o equivalente direto em x86_64: mesma 1 GiB de RAM, 2 vCPU,
  # geração mais nova. Confirmado via:
  #   aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true
  validation {
    condition     = contains(["t3.micro", "t2.micro", "t4g.micro"], var.instance_type)
    error_message = "Use um tipo free-tier-eligible: t3.micro (x86) ou t4g.micro (arm)."
  }
}

variable "api_port" {
  description = "Porta em que a API Node.js escuta."
  type        = number
  default     = 3000
}

variable "ssh_key_path" {
  description = "Onde salvar a chave privada gerada. Fora do repositório."
  type        = string
  default     = "~/.ssh/technova-key.pem"
}

locals {
  common_tags = {
    Project     = "TechNova"
    Environment = "development"
    ManagedBy   = "Terraform"
    Owner       = var.ra
    Disciplina  = "DevOps - UniFAAT 2026-2"
    Aula        = "04"
  }
}

# AZs disponíveis na região, descobertas em runtime.
# Fixar "us-east-1a" no código quebra a portabilidade entre regiões e entre
# contas — nem toda conta enxerga as mesmas AZs.
data "aws_availability_zones" "disponiveis" {
  state = "available"
}
