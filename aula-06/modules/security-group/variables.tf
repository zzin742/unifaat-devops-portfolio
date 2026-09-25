variable "name" {
  description = "Nome do Security Group (sem o prefixo de projeto/ambiente)"
  type        = string
}

variable "description" {
  description = "Descricao do SG. A AWS exige e nao permite alterar depois."
  type        = string
  default     = "Gerenciado pelo Terraform"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde o SG e criado"
  type        = string
}

variable "ingress_rules" {
  description = <<-DESC
    Regras de entrada como lista de objetos. Cada regra libera por CIDR
    (cidr_blocks) OU por Security Group de origem (source_security_group_id) —
    nunca os dois na mesma regra.

    Liberar por SG de origem e o que permite o RDS aceitar conexao apenas da
    EC2 da aplicacao: a regra aponta para o grupo, entao continua correta mesmo
    que o IP da instancia mude.

    Exemplo:
      [
        { description = "SSH",  from_port = 22,   to_port = 22,   cidr_blocks = ["0.0.0.0/0"] },
        { description = "psql", from_port = 5432, to_port = 5432, source_security_group_id = module.api_sg.sg_id },
      ]
  DESC
  type = list(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = optional(string, "tcp")
    cidr_blocks              = optional(list(string))
    source_security_group_id = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.ingress_rules :
      (r.cidr_blocks != null) != (r.source_security_group_id != null)
    ])
    error_message = "Cada regra deve informar cidr_blocks OU source_security_group_id, nunca ambos nem nenhum."
  }
}

variable "enable_default_egress" {
  description = "Cria a regra de egress liberando todo o trafego de saida"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}
