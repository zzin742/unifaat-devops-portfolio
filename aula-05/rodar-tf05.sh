#!/usr/bin/env bash
# TF-05 - execucao completa com captura de evidencias
# Aluno: Jose Henrique Teixeira Luiz - RA 3225002
#
# Pre-requisito: sessao do Learner Lab ativa e credenciais atualizadas
#   ~/Cortex/Faculdade/DevOps/scripts/aws-lab-creds.sh
#
# Uso: ./rodar-tf05.sh
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
EV="${BASE}/evidencias"
mkdir -p "${EV}"

titulo() { printf '\n\033[1m>> %s\033[0m\n' "$1"; }

# O destroy roda SEMPRE, inclusive se um passo falhar no meio. O RDS nao e
# desligado automaticamente entre sessoes do lab - deixar de pe consome o
# orcamento de USD 50 que, se estourar, apaga o ambiente inteiro.
limpar() {
  local status=$?
  titulo "LIMPEZA (status de saida: ${status})"

  cd "${BASE}"
  terraform destroy -auto-approve -no-color 2>&1 | tail -5 | tee "${EV}/99-destroy-principal.txt" || true

  if [ -n "${BUCKET:-}" ]; then
    echo ">> esvaziando o bucket (versionamento impede destroy com objetos)"
    aws s3 rm "s3://${BUCKET}" --recursive 2>&1 | tail -3 || true
  fi

  cd "${BASE}/backend"
  # -refresh=false pelo mesmo motivo do apply: a leitura de object lock e negada
  terraform destroy -auto-approve -no-color -refresh=false 2>&1 | tail -5 | tee "${EV}/99-destroy-backend.txt" || true

  titulo "conta limpa?"
  aws rds describe-db-instances --query 'length(DBInstances[])' --output text 2>&1 | xargs echo "  instancias RDS:"
  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running,pending" \
    --query 'length(Reservations[])' --output text 2>&1 | xargs echo "  EC2 ativas:"
  exit "${status}"
}

titulo "0/8 validando a sessao do lab"
aws sts get-caller-identity | tee "${EV}/00-identidade.txt"

titulo "1/8 backend: bucket S3 + tabela DynamoDB"
cd "${BASE}/backend"
terraform init -no-color -input=false

# A SCP do Learner Lab NEGA s3:GetBucketObjectLockConfiguration. O provider AWS
# v5 faz essa leitura logo apos criar um aws_s3_bucket, entao o primeiro apply
# aborta com AccessDenied - apesar de o bucket ter sido criado. O recurso fica
# marcado como tainted.
#
# O contorno: destravar o recurso e aplicar sem refresh, que pula a leitura
# bloqueada. As demais chamadas (versionamento, criptografia, public access
# block) sao permitidas e rodam normalmente.
terraform apply -auto-approve -no-color -input=false 2>&1 | tail -6 || {
  echo ">> primeiro apply abortou (esperado no Learner Lab); destravando"
  terraform untaint aws_s3_bucket.state || true
  terraform apply -auto-approve -no-color -input=false -refresh=false | tail -6
}
BUCKET="$(terraform output -raw bucket_state)"
TABELA="$(terraform output -raw tabela_lock)"
echo "  bucket: ${BUCKET}"
echo "  tabela: ${TABELA}"
trap limpar EXIT

titulo "2/8 apontando o backend do projeto principal para o bucket"
cd "${BASE}"
# O bloco backend nao aceita variaveis - o valor tem que ser literal.
sed -i '' "s|__PREENCHER_COM_O_OUTPUT_DO_BACKEND__|${BUCKET}|" providers.tf
grep -A2 'backend "s3"' providers.tf | sed 's/^/  /'

titulo "3/8 senha do banco (fora do Git)"
if [ ! -f terraform.tfvars ]; then
  SENHA="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
  printf 'db_password = "%s"\n' "${SENHA}" > terraform.tfvars
  chmod 600 terraform.tfvars
  echo "  gerada e salva em terraform.tfvars (no .gitignore)"
else
  echo "  ja existe, reaproveitando"
fi

titulo "4/8 migrando o state local para o S3"
terraform init -no-color -input=false -migrate-state -force-copy | tail -8

titulo "5/8 subindo VPC + RDS + EC2 (o RDS leva de 5 a 10 min)"
terraform apply -auto-approve -no-color -input=false | tail -20
terraform output -no-color | tee "${EV}/01-outputs.txt"

titulo "6/8 EVIDENCIA 1 - state remoto no S3"
{
  echo "=== bucket do state ==="
  aws s3 ls "s3://${BUCKET}/aula-05/"
  echo
  echo "=== versionamento (protege contra state corrompido) ==="
  aws s3api get-bucket-versioning --bucket "${BUCKET}"
  echo
  echo "=== criptografia em repouso ==="
  aws s3api get-bucket-encryption --bucket "${BUCKET}" \
    --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault'
  echo
  echo "=== bloqueio de acesso publico ==="
  aws s3api get-public-access-block --bucket "${BUCKET}" \
    --query 'PublicAccessBlockConfiguration'
  echo
  echo "=== tabela de lock ==="
  aws dynamodb describe-table --table-name "${TABELA}" \
    --query 'Table.{Nome:TableName,Chave:KeySchema[0],Status:TableStatus}'
} 2>&1 | tee "${EV}/02-state-no-s3.txt"

titulo "7/8 EVIDENCIA 2 e 3 - conexao EC2 -> RDS e dados persistidos"
IP="$(terraform output -raw ec2_public_ip)"
SENHA_DB="$(grep db_password terraform.tfvars | cut -d'"' -f2)"

echo ">> aguardando o user data instalar o psql"
for i in $(seq 1 30); do
  if ssh -i ~/.ssh/labsuser.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o ConnectTimeout=10 ec2-user@"${IP}" 'test -x /usr/local/bin/testar-rds.sh' 2>/dev/null; then
    echo "  pronto em ~$((i*10))s"; break
  fi
  sleep 10
done

ssh -i ~/.ssh/labsuser.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  ec2-user@"${IP}" "
    echo '=== teste automatico de alcance (do user data) ==='
    cat /var/log/technova-rds-check.log
    echo
    echo '=== teste autenticado ==='
    PGPASSWORD='${SENHA_DB}' /usr/local/bin/testar-rds.sh
  " 2>&1 | grep -v "Warning: Permanently added" | tee "${EV}/03-ec2-para-rds.txt"

titulo "8/8 EVIDENCIA 4 - plan limpo (infra em dia)"
terraform plan -no-color -detailed-exitcode 2>&1 | tail -6 | tee "${EV}/04-plan-limpo.txt" || true

titulo "evidencias capturadas"
ls -la "${EV}"
