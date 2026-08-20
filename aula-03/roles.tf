# ============================================================================
# Service Role — a aplicação na EC2 acessa o S3 sem credencial no disco
# ============================================================================
# Este é o ponto central da aula: em vez de gerar uma access key e deixá-la
# num .env dentro da instância, a EC2 ASSUME uma role. A AWS entrega
# credenciais temporárias, rotacionadas sozinhas, que nunca tocam o disco nem
# o repositório. Chave vazada deixa de ser um vetor.

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    sid     = "PermitirQueEC2AssumaEstaRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.prefix}-ec2-role"
  path               = "/${var.project_name}/"
  description        = "Role assumida pelas instancias EC2 da TechNova para acessar o S3 de dados."
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  # Sessão curta: mesmo que algo capture a credencial temporária, ela morre em 1h.
  max_session_duration = 3600

  tags = merge(local.common_tags, { Name = "${local.prefix}-ec2-role" })
}

# ============================================================================
# Permissões da role — escopo só nos buckets de dados da aplicação
# ============================================================================

resource "aws_iam_policy" "ec2_app_data" {
  name        = "${local.prefix}-ec2-app-data"
  path        = "/${var.project_name}/"
  description = "Read/write restrito aos buckets ${var.data_bucket_prefix}-*."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListarBucketsDeDados"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::${var.data_bucket_prefix}-*"]
      },
      {
        Sid    = "LerEEscreverObjetosDeDados"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = ["arn:aws:s3:::${var.data_bucket_prefix}-*/*"]
      },
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.prefix}-ec2-app-data" })
}

resource "aws_iam_role_policy_attachment" "ec2_app_data" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_app_data.arn
}

# ============================================================================
# Instance Profile — o "adaptador" entre a role e a EC2
# ============================================================================
# Uma EC2 não anexa uma role diretamente: ela recebe um instance profile, que
# por sua vez aponta pra role. É esse objeto que vai no argumento
# iam_instance_profile do aws_instance (usado na aula 04).

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.prefix}-ec2-profile"
  path = "/${var.project_name}/"
  role = aws_iam_role.ec2_role.name

  tags = merge(local.common_tags, { Name = "${local.prefix}-ec2-profile" })
}
