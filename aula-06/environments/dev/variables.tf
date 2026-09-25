variable "aws_region" {
  description = "Regiao AWS. O AWS Academy Learner Lab so autoriza us-east-1."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "O AWS Academy Learner Lab so permite recursos em us-east-1."
  }
}

variable "project_name" {
  description = "Nome do projeto — compoe o padrao de nomes de todos os recursos"
  type        = string
  default     = "technova"
}

variable "environment" {
  description = "Ambiente deste diretorio"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC deste ambiente"
  type        = string
}

variable "subnets" {
  description = "Mapa de subnets repassado ao modulo vpc"
  type = map(object({
    cidr = string
    az   = string
    type = string
  }))
}

variable "instance_type" {
  description = "Tipo da EC2 da API"
  type        = string
  default     = "t2.micro"
}

variable "ssh_allowed_cidrs" {
  description = <<-DESC
    CIDRs autorizados a abrir SSH. O default 0.0.0.0/0 existe so para nao travar
    a correcao; o certo e passar o proprio IP: ["203.0.113.10/32"].
  DESC
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_name" {
  description = "Nome do database"
  type        = string
}

variable "db_username" {
  description = "Usuario master do banco"
  type        = string
  default     = "technova_app"
}

variable "db_password" {
  description = "Senha master do banco. Passe por TF_VAR_db_password."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Classe da instancia RDS"
  type        = string
  default     = "db.t3.micro"
}
