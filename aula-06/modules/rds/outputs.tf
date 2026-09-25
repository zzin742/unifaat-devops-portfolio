output "db_endpoint" {
  description = "Endpoint do RDS no formato host:porta"
  value       = aws_db_instance.este.endpoint
}

output "db_host" {
  description = "Apenas o host — e o valor que vai em DB_HOST na aplicacao"
  value       = aws_db_instance.este.address
}

output "db_name" {
  description = "Nome do database criado"
  value       = aws_db_instance.este.db_name
}

output "db_port" {
  description = "Porta do banco"
  value       = aws_db_instance.este.port
}

output "db_subnet_group_name" {
  description = "DB Subnet Group usado (evidencia de que o banco esta nas privadas)"
  value       = aws_db_subnet_group.este.name
}
