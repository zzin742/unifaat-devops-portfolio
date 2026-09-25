output "instance_id" {
  description = "ID da instancia criada"
  value       = aws_instance.esta.id
}

output "public_ip" {
  description = "IP publico da instancia (vazio em subnet privada)"
  value       = aws_instance.esta.public_ip
}

output "private_ip" {
  description = "IP privado da instancia dentro da VPC"
  value       = aws_instance.esta.private_ip
}

output "public_dns" {
  description = "DNS publico da instancia"
  value       = aws_instance.esta.public_dns
}

output "availability_zone" {
  description = "AZ em que a instancia subiu"
  value       = aws_instance.esta.availability_zone
}
