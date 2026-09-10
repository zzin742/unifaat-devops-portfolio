output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.main.id
}

output "subnet_publica" {
  description = "ID da subnet publica (EC2)."
  value       = aws_subnet.public.id
}

output "subnets_privadas" {
  description = "IDs das subnets privadas (RDS)."
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "azs_das_subnets_privadas" {
  description = "AZs das subnets privadas - evidencia do requisito de 2 AZs."
  value       = { for k, s in aws_subnet.private : k => s.availability_zone }
}

output "ec2_public_ip" {
  description = "IP publico da EC2."
  value       = aws_instance.app.public_ip
}

output "rds_endpoint" {
  description = "Endpoint do RDS (host:porta)."
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "Hostname do RDS, sem a porta."
  value       = aws_db_instance.main.address
}

output "rds_publicamente_acessivel" {
  description = "Deve ser false - evidencia de que o banco esta isolado."
  value       = aws_db_instance.main.publicly_accessible
}

output "rds_criptografado" {
  description = "Deve ser true - evidencia de criptografia em repouso."
  value       = aws_db_instance.main.storage_encrypted
}

output "instance_profile_usado" {
  description = "Instance profile do lab reusado - nada de IAM foi criado."
  value       = data.aws_iam_instance_profile.lab.arn
}

output "ssh_command" {
  description = "Comando para conectar na EC2."
  value       = "ssh -i ${var.ssh_key_path} ec2-user@${aws_instance.app.public_ip}"
}

# A connection string sai marcada como sensitive porque carrega o usuario e o
# host do banco. A senha nunca entra aqui - ela vem do ambiente na hora de usar.
output "connection_string" {
  description = "String de conexao psql (sem a senha)."
  value       = "psql -h ${aws_db_instance.main.address} -U ${var.db_username} -d ${var.db_name}"
  sensitive   = true
}

output "comando_teste_rds" {
  description = "Como rodar o teste de conexao autenticada dentro da EC2."
  value       = "PGPASSWORD='<senha>' /usr/local/bin/testar-rds.sh"
}
