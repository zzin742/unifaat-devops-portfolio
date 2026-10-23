# variables.tf — aula-10

variable "regiao" {
  description = "Regiao AWS obrigatoria do Learner Lab."
  type        = string
  default     = "us-east-1"
}

variable "projeto" {
  description = "Prefixo usado nos nomes dos recursos."
  type        = string
  default     = "technova-aula10"
}

variable "instance_type" {
  description = "Tipo da instancia EC2 que recebe o deploy."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Par de chaves para o SSH. No Learner Lab o par pronto chama-se 'vockey'."
  type        = string
  default     = "vockey"
}

variable "instance_profile" {
  description = "Instance profile pre-provisionado do Learner Lab (nao e permitido criar roles)."
  type        = string
  default     = "LabInstanceProfile"
}

variable "ambiente_label" {
  description = "Rotulo de ambiente aplicado como tag — usado para demonstrar o plan no PR."
  type        = string
  default     = "homologacao"
}

variable "app_port" {
  description = "Porta em que a TechNova API escuta."
  type        = number
  default     = 3000
}

variable "ssh_cidr" {
  description = "De onde o SSH e aceito. O runner do GitHub Actions tem IP variavel, por isso 0.0.0.0/0 — ver a ressalva em gitops-cd-analise.md."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags de custo aplicadas a todos os recursos (via default_tags)."
  type        = map(string)
  default = {
    Projeto    = "aula-10-gitops-cd"
    Disciplina = "DevOps"
    Ambiente   = "LearnerLab"
    RA         = "3225002"
  }
}
