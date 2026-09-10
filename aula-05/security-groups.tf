# ============================================================================
# Security Groups
# ============================================================================

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2 da aplicacao: SSH e API"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.meu_ip_ssh]
  }

  ingress {
    description = "API da aplicacao"
    from_port   = var.api_port
    to_port     = var.api_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida liberada: precisa baixar pacotes e o cliente psql"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2-sg"
  })
}

# ============================================================================
# Security Group do banco - DESAFIO EXTRA 1
# ============================================================================
# O enunciado aceita liberar a 5432 para o CIDR inteiro da VPC. Aqui a origem
# e o SECURITY GROUP da EC2, que e mais restrito por dois motivos:
#
#   1. Qualquer recurso futuro dentro de 10.0.0.0/16 herdaria acesso ao banco
#      pelo CIDR. Pelo SG, so quem estiver explicitamente naquele grupo entra.
#   2. Trocar o CIDR da VPC nao afrouxa a regra sem querer.
#
# E o mesmo principio de menor privilegio da aula 03, agora em rede: restringir
# pela identidade da origem, nao pelo endereco dela.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "PostgreSQL acessivel apenas pela EC2 da aplicacao"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL vindo somente do SG da EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Sem regra de egress: o banco nao inicia conexao com ninguem. O egress
  # default de um SG novo ja e vazio - o bloco acima e o unico caminho.

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-sg"
  })
}
