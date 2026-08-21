# ============================================================================
# Role assumida pela EC2
# ============================================================================
# Mesmo princípio da aula 03: a aplicação recebe credencial temporária da AWS
# em vez de carregar access key no disco. A diferença é que aqui usamos a
# policy gerenciada AmazonS3ReadOnlyAccess, conforme o enunciado pede.

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.ra}-${var.project_name}-ec2-role-a04"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2-role"
  })
}

resource "aws_iam_role_policy_attachment" "s3_readonly" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.ra}-${var.project_name}-ec2-profile-a04"
  role = aws_iam_role.ec2.name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2-profile"
  })
}
