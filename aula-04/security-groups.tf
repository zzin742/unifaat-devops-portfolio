# ============================================================================
# Security Group da API
# ============================================================================
# SSH e a porta da API abertos para 0.0.0.0/0 porque o enunciado pede assim —
# e porque o professor precisa alcançar a instância para corrigir.
#
# Em produção isto NÃO se faz: SSH ficaria restrito ao IP do escritório ou,
# melhor, substituído por AWS Systems Manager Session Manager, que dispensa
# porta 22 aberta e chave privada circulando.

resource "aws_security_group" "api" {
  name        = "${var.project_name}-api-sg"
  description = "Permite SSH e acesso HTTP a API Node.js"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API Node.js"
    from_port   = var.api_port
    to_port     = var.api_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida liberada: a instancia precisa baixar Node, git e npm"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-api-sg"
  })
}

# ============================================================================
# Security Group do banco (preparado para uso futuro)
# ============================================================================
# Aqui está o menor privilégio de verdade: 5432 aberta APENAS para dentro da
# VPC (10.0.0.0/16). Um Postgres nesta subnet é inalcançável da internet,
# mesmo que alguém o coloque numa subnet pública por engano.

resource "aws_security_group" "database" {
  name        = "${var.project_name}-db-sg"
  description = "PostgreSQL acessivel somente de dentro da VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL apenas da rede interna"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-sg"
  })
}
