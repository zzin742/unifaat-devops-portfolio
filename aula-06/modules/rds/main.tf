# Modulo RDS — PostgreSQL gerenciado em subnets privadas.

locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_db_subnet_group" "este" {
  name        = "${local.name}-db-subnet-group"
  description = "Subnets privadas onde o RDS de ${var.environment} pode subir"
  subnet_ids  = var.subnet_ids

  tags = merge(local.common_tags, { Name = "${local.name}-db-subnet-group" })
}

resource "aws_db_instance" "este" {
  identifier = "${local.name}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  # Encriptacao em repouso nao e alteravel depois da criacao: ligar num banco
  # existente obriga a recriar a instancia.
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.este.name
  vpc_security_group_ids = var.security_group_ids

  # Sem endpoint publico. Com true, o RDS ganharia DNS resolvivel pela internet
  # e a unica barreira restante seria o Security Group.
  publicly_accessible = false

  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false

  # Configuracoes de ambiente descartavel, como pede o enunciado: sem backup e
  # sem snapshot final, para o destroy ser rapido e nao consumir credito do Lab.
  # Em producao seria o oposto: retention >= 7 e skip_final_snapshot = false.
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = merge(local.common_tags, { Name = "${local.name}-postgres" })
}
