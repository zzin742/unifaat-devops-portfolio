output "sg_id" {
  description = "ID do Security Group — usado como origem em regras de outros SGs"
  value       = aws_security_group.este.id
}

output "sg_name" {
  description = "Nome completo do Security Group"
  value       = aws_security_group.este.name
}

output "sg_arn" {
  description = "ARN do Security Group"
  value       = aws_security_group.este.arn
}
