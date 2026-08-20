# ============================================================================
# IAM Groups — separação por responsabilidade, não por pessoa
# ============================================================================
# Permissão é anexada ao grupo, nunca ao usuário. Quando alguém entra ou sai
# do time, muda-se a associação — as policies ficam intactas.

resource "aws_iam_group" "developers" {
  name = "${local.prefix}-developers"
  path = "/${var.project_name}/"
}

resource "aws_iam_group" "platform_eng" {
  name = "${local.prefix}-platform-eng"
  path = "/${var.project_name}/"
}

# ============================================================================
# IAM Users
# ============================================================================
# NOTA: aws_iam_group não aceita tags (limitação da API do IAM — grupos não são
# taggable). Users e roles aceitam, e recebem as tags obrigatórias abaixo.

resource "aws_iam_user" "juliana_dev" {
  name = "${local.prefix}-juliana-dev"
  path = "/${var.project_name}/"

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-juliana-dev"
    Role = "Developer"
  })
}

resource "aws_iam_user" "rafael_platform" {
  name = "${local.prefix}-rafael-platform"
  path = "/${var.project_name}/"

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-rafael-platform"
    Role = "Platform Engineer"
  })
}

resource "aws_iam_user" "lucas_intern" {
  name = "${local.prefix}-lucas-intern"
  path = "/${var.project_name}/"

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-lucas-intern"
    Role = "Intern"
  })
}

# ============================================================================
# Memberships
# ============================================================================
# Rafael participa dos DOIS grupos: as permissões se somam. Ele mantém a
# leitura de S3 que todo dev tem e ganha a gestão de EC2 por cima.

resource "aws_iam_user_group_membership" "juliana_dev" {
  user   = aws_iam_user.juliana_dev.name
  groups = [aws_iam_group.developers.name]
}

resource "aws_iam_user_group_membership" "rafael_platform" {
  user = aws_iam_user.rafael_platform.name
  groups = [
    aws_iam_group.developers.name,
    aws_iam_group.platform_eng.name,
  ]
}

resource "aws_iam_user_group_membership" "lucas_intern" {
  user   = aws_iam_user.lucas_intern.name
  groups = [aws_iam_group.developers.name]
}

# ============================================================================
# Restrição extra do estagiário
# ============================================================================
# Lucas está em developers, mas é estagiário. Em vez de criar um grupo quase
# idêntico só pra ele, uso uma policy inline com Deny: o Deny vence qualquer
# Allow herdado do grupo, então ele fica com leitura de fato.

resource "aws_iam_user_policy" "lucas_intern_readonly" {
  name = "${local.prefix}-lucas-intern-readonly"
  user = aws_iam_user.lucas_intern.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyQualquerEscritaS3"
        Effect = "Deny"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutBucketPolicy",
          "s3:PutObjectAcl",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyMudancaDeEstadoEC2"
        Effect = "Deny"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RunInstances",
        ]
        Resource = "*"
      },
    ]
  })
}
