output "bucket_state" {
  description = "Nome do bucket S3 do state. Vai no backend do projeto principal."
  value       = aws_s3_bucket.state.id
}

output "tabela_lock" {
  description = "Nome da tabela DynamoDB de lock."
  value       = aws_dynamodb_table.lock.name
}

# Bloco pronto para colar em ../providers.tf, com o nome do bucket ja
# preenchido - o backend nao aceita variaveis, entao o valor tem que ser
# literal.
output "bloco_backend" {
  description = "Configuracao de backend pronta para o projeto principal."
  value       = <<-EOT

    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.state.id}"
        key            = "aula-05/terraform.tfstate"
        region         = "${var.aws_region}"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.lock.name}"
      }
    }
  EOT
}
