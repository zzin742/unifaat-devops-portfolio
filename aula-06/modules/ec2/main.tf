# Modulo EC2 — instancia reutilizavel.
#
# A AMI entra como variavel, nao como data source interno: assim o mesmo modulo
# serve para Amazon Linux, Ubuntu ou uma AMI propria, e quem escolhe e o
# ambiente. Fixar um ID de AMI aqui quebraria o modulo em outra regiao.

locals {
  name = "${var.project_name}-${var.environment}-${var.instance_name}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_instance" "esta" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  key_name             = var.key_name
  iam_instance_profile = var.iam_instance_profile

  user_data                   = var.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true

    tags = merge(local.common_tags, { Name = "${local.name}-root" })
  }

  # IMDSv2 obrigatorio. Com http_tokens = "optional", um SSRF na aplicacao
  # conseguiria ler as credenciais da role por um GET simples no endpoint de
  # metadados. O "required" exige um PUT com token antes de qualquer leitura.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, { Name = local.name })
}
