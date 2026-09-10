# ============================================================================
# AMI - resolvida em runtime
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
# Instance Profile - DESAFIO EXTRA 3
# ============================================================================
# O desafio pede um instance profile com permissao minima para a EC2. No AWS
# Academy Learner Lab a sessao assume o papel `voclabs`, que NAO tem permissao
# de criar entidades do IAM - `iam:CreateUser` e `iam:CreateRole` retornam
# AccessDenied (verificado).
#
# O lab entrega `LabRole` e `LabInstanceProfile` prontos. O caminho e
# referenciar por data source. O beneficio pratico que o desafio busca se
# mantem: a instancia recebe credencial temporaria pelo metadata service, sem
# access key gravada em disco.
#
# Ressalva honesta: a LabRole NAO e de menor privilegio - ela permite
# s3:CreateBucket, ec2:Describe* e iam:List*. No ambiente do lab nao ha como
# entregar uma role restrita, porque criar role e justamente o que ele bloqueia.
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

# ============================================================================
# EC2 da aplicacao
# ============================================================================
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = var.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name

  # O user data e um script bash cheio de ${VAR} do proprio shell. Passar por
  # templatefile() exigiria escapar cada um como $${VAR} - ruido que esconde
  # erro. replace() troca so os marcadores que nos definimos.
  #
  # .address e o hostname puro; .endpoint viria como "host:5432" e quebraria
  # o /dev/tcp/HOST/5432 do teste.
  user_data = replace(
    replace(
      replace(
        file("${path.module}/user_data.sh"),
        "__RDS_ENDPOINT__", aws_db_instance.main.address
      ),
      "__DB_USER__", var.db_username
    ),
    "__DB_NAME__", var.db_name
  )

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
    Name = "${var.project_name}-app"
  })
}
