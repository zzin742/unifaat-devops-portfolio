output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas."
  value       = [for s in aws_subnet.private : s.id]
}

output "api_security_group_id" {
  description = "ID do security group da API."
  value       = aws_security_group.api.id
}

output "db_security_group_id" {
  description = "ID do security group do banco."
  value       = aws_security_group.database.id
}

output "ec2_public_ip" {
  description = "IP publico da instancia EC2."
  value       = aws_instance.api.public_ip
}

output "api_url" {
  description = "URL completa da API."
  value       = "http://${aws_instance.api.public_ip}:${var.api_port}"
}

output "ssh_command" {
  description = "Comando pronto para conectar na instancia."
  value       = "ssh -i ${var.ssh_key_path} ec2-user@${aws_instance.api.public_ip}"
}

output "availability_zones_usadas" {
  description = "AZs em que as subnets foram distribuidas (evidencia do Multi-AZ)."
  value = {
    publicas = { for k, s in aws_subnet.public : k => s.availability_zone }
    privadas = { for k, s in aws_subnet.private : k => s.availability_zone }
  }
}
