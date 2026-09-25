variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "db_name" {
  description = "Nome do database criado na instancia"
  type        = string
}

variable "db_username" {
  description = "Usuario master do PostgreSQL"
  type        = string
}

variable "db_password" {
  description = "Senha do usuario master. Vem de TF_VAR_db_password, nunca do codigo."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "O RDS exige senha com no minimo 8 caracteres."
  }
}

variable "subnet_ids" {
  description = "Subnets privadas do DB Subnet Group (minimo 2 AZs)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "O DB Subnet Group exige subnets em no minimo 2 AZs."
  }
}

variable "security_group_ids" {
  description = "Security Groups do banco"
  type        = list(string)
}

variable "instance_class" {
  description = "Classe da instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "Versao major do PostgreSQL"
  type        = string
  default     = "16"
}

variable "allocated_storage" {
  description = "Armazenamento alocado em GB (minimo do gp3 no RDS e 20)"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}
