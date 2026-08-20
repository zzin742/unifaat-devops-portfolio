# ============================================================================
# Policy 1 — Leitura de S3 para desenvolvedores
# ============================================================================
# Menor privilégio em dois eixos:
#   Ação   -> só GetObject e ListBucket. Nada de Put, Delete ou mudar policy.
#   Recurso-> só buckets que começam com "technova-". Um bucket de RH na mesma
#             conta continua invisível pro time de desenvolvimento.

resource "aws_iam_policy" "s3_read" {
  name        = "${local.prefix}-s3-read"
  path        = "/${var.project_name}/"
  description = "Leitura de objetos nos buckets technova-* (desenvolvedores)."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListarBucketsDoProjeto"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        # ListBucket age sobre o bucket, não sobre o objeto — ARN sem /*
        Resource = ["arn:aws:s3:::${var.project_name}-*"]
      },
      {
        Sid    = "LerObjetosDoProjeto"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        # GetObject age sobre o objeto — ARN precisa do /*
        Resource = ["arn:aws:s3:::${var.project_name}-*/*"]
      },
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.prefix}-s3-read" })
}

# ============================================================================
# Policy 2 — EC2 + S3 para Platform Engineering
# ============================================================================
# O Start/Stop é limitado por Condition de tag: só instância marcada como
# Project=TechNova pode ser ligada ou desligada. Se alguém subir uma EC2 de
# outro projeto na mesma conta, o time não alcança.

resource "aws_iam_policy" "ec2_s3_full" {
  name        = "${local.prefix}-ec2-s3-full"
  path        = "/${var.project_name}/"
  description = "Gestao de EC2 do projeto (com condition de tag) e read/write em S3."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InventarioEC2SomenteLeitura"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
        ]
        # As ações Describe* não suportam ARN específico na API da AWS.
        # Compensamos limitando a "*" apenas para leitura, nunca para escrita.
        Resource = "*"
      },
      {
        Sid    = "LigarDesligarSomenteInstanciasDoProjeto"
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "TechNova"
          }
        }
      },
      {
        Sid    = "EscritaS3NosBucketsDoProjeto"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*",
        ]
      },
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.prefix}-ec2-s3-full" })
}

# ============================================================================
# Policy 3 — Deny explícito de operações destrutivas
# ============================================================================
# Rede de segurança. Na avaliação de policy da AWS, um Deny explícito vence
# QUALQUER Allow, inclusive de uma policy gerenciada anexada por engano.
# Se amanhã alguém anexar AmazonS3FullAccess a este grupo, o DeleteBucket
# continua bloqueado.

resource "aws_iam_policy" "deny_destructive" {
  name        = "${local.prefix}-deny-destructive"
  path        = "/${var.project_name}/"
  description = "Deny explicito de exclusao e terminacao. Prevalece sobre qualquer Allow."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProibirExclusaoEDestruicao"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "ec2:TerminateInstances",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteSecurityGroup",
          "rds:DeleteDBInstance",
          "iam:DeleteUser",
          "iam:DeleteRole",
          "iam:DeletePolicy",
        ]
        Resource = "*"
      },
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.prefix}-deny-destructive" })
}

# ============================================================================
# Attachments
# ============================================================================

resource "aws_iam_group_policy_attachment" "developers_s3_read" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_group_policy_attachment" "developers_deny_destructive" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.deny_destructive.arn
}

resource "aws_iam_group_policy_attachment" "platform_eng_ec2_s3" {
  group      = aws_iam_group.platform_eng.name
  policy_arn = aws_iam_policy.ec2_s3_full.arn
}
