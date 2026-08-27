# ============================================================================
# IAM no AWS Academy Learner Lab: reusar, nao criar
# ============================================================================
# A diferenca central em relacao a aula-04/ (feita em conta AWS propria).
#
# Naquela versao o Terraform CRIAVA a role, o instance profile e o attachment
# da policy - 3 recursos IAM. Aqui isso nao e possivel: a sessao do lab assume
# o papel `voclabs`, que nao tem permissao de criar entidades do IAM.
#
# O lab ja entrega prontos:
#   - LabRole            -> role com as permissoes liberadas para os labs
#   - LabInstanceProfile -> instance profile ja associado a LabRole
#
# O caminho e referenciar por data source. O ganho de seguranca da aula-04
# continua valendo: a EC2 recebe credencial temporaria via instance profile,
# em vez de carregar access key em disco.

data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}
