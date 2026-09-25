output "environment" {
  description = "Ambiente provisionado por este diretorio"
  value       = var.environment
}

output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR da VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Subnets publicas (EC2)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Subnets privadas (RDS)"
  value       = module.vpc.private_subnet_ids
}

output "api_sg_id" {
  description = "SG da API — e a origem autorizada na regra 5432 do banco"
  value       = module.api_sg.sg_id
}

output "rds_sg_id" {
  description = "SG do RDS"
  value       = module.rds_sg.sg_id
}

output "api_instance_id" {
  description = "ID da instancia da API"
  value       = module.api_server.instance_id
}

output "api_public_ip" {
  description = "IP publico da API"
  value       = module.api_server.public_ip
}

output "api_url" {
  description = "URL da API"
  value       = "http://${module.api_server.public_ip}:3000"
}

output "ssh_command" {
  description = "Comando de acesso SSH (labsuser.pem vem do Learner Lab)"
  value       = "ssh -i ~/.ssh/labsuser.pem ec2-user@${module.api_server.public_ip}"
}

output "db_endpoint" {
  description = "Endpoint do RDS — alcancavel apenas de dentro da VPC"
  value       = module.database.db_endpoint
}

output "db_name" {
  description = "Nome do database"
  value       = module.database.db_name
}

output "db_port" {
  description = "Porta do banco"
  value       = module.database.db_port
}
