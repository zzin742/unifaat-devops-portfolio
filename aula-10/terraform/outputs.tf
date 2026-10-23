# outputs.tf — aula-10
# Estes valores sao consumidos pelo job de deploy do cd.yml.

output "instance_public_ip" {
  description = "IP publico da EC2 — destino do SSH no job de deploy."
  value       = aws_instance.api.public_ip
}

output "instance_id" {
  description = "Id da instancia."
  value       = aws_instance.api.id
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR — destino do push da imagem."
  value       = aws_ecr_repository.api.repository_url
}

output "health_url" {
  description = "Endereco do health check usado apos o deploy."
  value       = "http://${aws_instance.api.public_ip}:${var.app_port}/health"
}

output "security_group_id" {
  description = "Id do security group da aplicacao."
  value       = aws_security_group.api.id
}
