output "iam_users" {
  description = "Usuarios IAM criados e o ARN de cada um."
  value = {
    juliana_dev     = aws_iam_user.juliana_dev.arn
    rafael_platform = aws_iam_user.rafael_platform.arn
    lucas_intern    = aws_iam_user.lucas_intern.arn
  }
}

output "iam_groups" {
  description = "Grupos IAM criados."
  value = {
    developers   = aws_iam_group.developers.arn
    platform_eng = aws_iam_group.platform_eng.arn
  }
}

output "policy_arns" {
  description = "ARNs das custom policies."
  value = {
    s3_read          = aws_iam_policy.s3_read.arn
    ec2_s3_full      = aws_iam_policy.ec2_s3_full.arn
    deny_destructive = aws_iam_policy.deny_destructive.arn
    ec2_app_data     = aws_iam_policy.ec2_app_data.arn
  }
}

output "ec2_role_arn" {
  description = "ARN da service role assumida pelas instancias EC2."
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "Nome do instance profile. Usado no iam_instance_profile da aula 04."
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "resumo" {
  description = "Contagem dos recursos criados, para conferencia rapida."
  value = {
    grupos           = 2
    usuarios         = 3
    custom_policies  = 4
    service_roles    = 1
    instance_profile = 1
  }
}
