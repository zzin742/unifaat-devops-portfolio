variable "project_name" {
  description = "Nome do projeto — compoe o padrao de nomes technova-<env>-*"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr deve ser um CIDR valido (ex: 10.0.0.0/16)."
  }
}

variable "subnets" {
  description = <<-DESC
    Mapa de subnets. A chave e o nome logico da subnet e vira parte do Name do
    recurso. O campo type aceita "public" ou "private" e determina se a subnet
    recebe IP publico e rota para o Internet Gateway.

    Exemplo:
      {
        "public-1a"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public" }
        "private-1a" = { cidr = "10.0.3.0/24", az = "us-east-1a", type = "private" }
      }
  DESC
  type = map(object({
    cidr = string
    az   = string
    type = string
  }))

  validation {
    condition     = alltrue([for s in var.subnets : contains(["public", "private"], s.type)])
    error_message = "O campo type de cada subnet deve ser \"public\" ou \"private\"."
  }

  validation {
    condition     = length([for s in var.subnets : s if s.type == "private"]) >= 2
    error_message = "Sao necessarias no minimo 2 subnets privadas: o DB Subnet Group do RDS exige 2 AZs."
  }
}

variable "tags" {
  description = "Tags adicionais aplicadas aos recursos do modulo"
  type        = map(string)
  default     = {}
}
