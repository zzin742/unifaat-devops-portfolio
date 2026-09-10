# ============================================================================
# RDS PostgreSQL
# ============================================================================
# Banco gerenciado: a AWS cuida de patch, backup e failover. O que continua
# nosso e o desenho de rede e o controle de acesso - que e onde este arquivo
# concentra as decisoes.

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"

  # Criptografia em repouso. Nao da para ligar depois em uma instancia
  # existente - so recriando a partir de um snapshot. Tem que nascer assim.
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # As duas linhas que mantem o banco privado:
  #   publicly_accessible = false -> sem endereco publico
  #   subnets sem rota para o IGW -> sem caminho de saida
  # Uma sozinha nao basta.
  publicly_accessible = false

  multi_az = false # laboratorio: standby em outra AZ dobraria o custo

  # Aceitavel apenas em laboratorio: em producao, pular o snapshot final
  # significa destruir o banco sem chance de recuperar os dados.
  skip_final_snapshot = true

  # Sem retencao de backup: o Learner Lab cobra armazenamento de snapshot, e
  # este banco e descartavel.
  backup_retention_period = 0

  # Sem janela de manutencao automatica durante o laboratorio: uma atualizacao
  # de versao no meio da captura de evidencia derrubaria a conexao.
  auto_minor_version_upgrade = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db"
  })
}
