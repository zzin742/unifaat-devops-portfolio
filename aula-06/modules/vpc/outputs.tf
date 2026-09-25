output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.esta.id
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = aws_vpc.esta.cidr_block
}

output "public_subnet_ids" {
  description = "Lista de IDs das subnets publicas, ordenada pela chave do mapa"
  value       = [for nome in sort(keys(local.public_subnets)) : aws_subnet.esta[nome].id]
}

output "private_subnet_ids" {
  description = "Lista de IDs das subnets privadas, ordenada pela chave do mapa"
  value       = [for nome in sort(keys(local.private_subnets)) : aws_subnet.esta[nome].id]
}

output "subnet_ids_by_name" {
  description = "Mapa nome logico => ID, para quem precisa de uma subnet especifica"
  value       = { for nome, s in aws_subnet.esta : nome => s.id }
}

output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = aws_internet_gateway.esta.id
}
