variable "instance_name" {
  description = "Nome logico da instancia (compoe o Name final)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI da instancia. Resolvida por data source no ambiente, nao fixada aqui."
  type        = string
}

variable "instance_type" {
  description = "Tipo da instancia"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet onde a instancia sobe"
  type        = string
}

variable "security_group_ids" {
  description = "Security Groups associados a instancia"
  type        = list(string)
}

variable "key_name" {
  description = "Key pair para SSH. No AWS Academy Learner Lab e a 'vockey'."
  type        = string
  default     = "vockey"
}

variable "iam_instance_profile" {
  description = <<-DESC
    Instance profile da instancia. No Learner Lab tem de ser o
    LabInstanceProfile pre-existente: o Lab nega iam:CreateRole, entao nao ha
    como criar um profile proprio. null nao associa nenhum.
  DESC
  type        = string
  default     = "LabInstanceProfile"
}

variable "user_data" {
  description = "Script de bootstrap (opcional)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Tamanho do volume raiz em GB"
  type        = number
  default     = 8
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}
