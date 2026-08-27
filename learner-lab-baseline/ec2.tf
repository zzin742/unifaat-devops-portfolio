# ============================================================================
# AMI - descoberta em runtime, nunca fixada
# ============================================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================================
# Instancia da API
# ============================================================================
# Duas diferencas em relacao a aula-04/, ambas impostas pelo Learner Lab:
#   key_name             -> `vockey`, que ja existe no lab
#   iam_instance_profile -> `LabInstanceProfile`, lido por data source
# O resto do desenho e identico: subnet publica para o curl da evidencia,
# IMDSv2 obrigatorio e volume raiz criptografado.

resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public["public-a"].id
  vpc_security_group_ids = [aws_security_group.api.id]
  key_name               = var.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  # IMDSv2 obrigatorio: bloqueia o SSRF classico em que uma requisicao forjada
  # pela aplicacao le as credenciais da role no endpoint de metadados.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-api"
  })
}
