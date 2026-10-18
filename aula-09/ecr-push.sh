#!/usr/bin/env bash
# ecr-push.sh — cria o repositorio no Amazon ECR, autentica, builda e publica
# a imagem da TechNova API com tags rastreaveis.
#
# Learner Lab: as credenciais sao TEMPORARIAS (tem aws_session_token) e expiram
# a cada sessao. Nao e possivel criar usuarios/roles IAM, entao a autenticacao
# usa as credenciais da propria sessao.
#
#   ./ecr-push.sh            # publica sha-XXXXXXX e latest
#   ./ecr-push.sh v1.2.3     # publica tambem 1.2.3, 1.2 e 1
set -euo pipefail

REGIAO="${AWS_REGION:-us-east-1}"
REPO="${ECR_REPO:-technova-api}"
VERSAO="${1:-}"

cor() { printf '\033[1;36m%s\033[0m\n' "$*"; }
erro() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

# ----------------------------------------------------------- pre-requisitos
command -v aws >/dev/null    || { erro "AWS CLI nao encontrado."; exit 1; }
command -v docker >/dev/null || { erro "Docker nao encontrado."; exit 1; }
docker info >/dev/null 2>&1  || { erro "Docker daemon nao esta rodando."; exit 1; }

cor "==> Conferindo as credenciais da sessao"
if ! CONTA=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
  erro "Credenciais invalidas ou expiradas."
  erro "Pegue as novas em 'AWS Details' no Learner Lab e reexporte."
  exit 1
fi
REGISTRY="${CONTA}.dkr.ecr.${REGIAO}.amazonaws.com"
echo "    conta ....: ${CONTA:0:4}********"
echo "    regiao ...: ${REGIAO}"

# ------------------------------------------------- repositorio (idempotente)
cor "==> Garantindo o repositorio ECR '${REPO}'"
if aws ecr describe-repositories --repository-names "$REPO" --region "$REGIAO" >/dev/null 2>&1; then
  echo "    ja existe"
else
  aws ecr create-repository \
    --repository-name "$REPO" \
    --region "$REGIAO" \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE \
    --query 'repository.repositoryUri' --output text
  echo "    criado com scan on push habilitado"
fi

# ------------------------------------------------- BONUS: lifecycle policy
cor "==> Aplicando lifecycle policy (mantem 10 imagens; expira untagged em 7 dias)"
aws ecr put-lifecycle-policy --repository-name "$REPO" --region "$REGIAO" \
  --lifecycle-policy-text '{
    "rules": [
      {
        "rulePriority": 1,
        "description": "Expira imagens sem tag apos 7 dias",
        "selection": {"tagStatus":"untagged","countType":"sinceImagePushed","countUnit":"days","countNumber":7},
        "action": {"type":"expire"}
      },
      {
        "rulePriority": 2,
        "description": "Mantem apenas as 10 imagens sha- mais recentes",
        "selection": {"tagStatus":"tagged","tagPrefixList":["sha-"],"countType":"imageCountMoreThan","countNumber":10},
        "action": {"type":"expire"}
      }
    ]
  }' --query 'repositoryName' --output text >/dev/null
echo "    aplicada"

# ---------------------------------------------------------------- login
cor "==> Login no ECR"
aws ecr get-login-password --region "$REGIAO" \
  | docker login --username AWS --password-stdin "$REGISTRY" >/dev/null
echo "    autenticado em ${REGISTRY}"

# ----------------------------------------------------------------- tags
SHA_CURTO=$(git rev-parse --short HEAD 2>/dev/null || echo "sem-git")
TAGS=("sha-${SHA_CURTO}" "latest")

# Semver a partir de v1.2.3 -> 1.2.3, 1.2 e 1
if [ -z "$VERSAO" ]; then
  VERSAO=$(git describe --tags --exact-match 2>/dev/null || echo "")
fi
if [[ "$VERSAO" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MA="${BASH_REMATCH[1]}"; MI="${BASH_REMATCH[2]}"; PA="${BASH_REMATCH[3]}"
  TAGS+=("${MA}.${MI}.${PA}" "${MA}.${MI}" "${MA}")
  echo "    semver detectado: ${MA}.${MI}.${PA}"
fi

cor "==> Tags que serao publicadas"
printf '    %s\n' "${TAGS[@]}"

# ---------------------------------------------------------------- build
cor "==> Build da imagem (multi-stage)"
ARGS=()
for t in "${TAGS[@]}"; do ARGS+=(-t "${REGISTRY}/${REPO}:${t}"); done
docker build "${ARGS[@]}" .

# ----------------------------------------------------------------- push
cor "==> Push para o ECR"
for t in "${TAGS[@]}"; do
  echo "    -> ${t}"
  docker push --quiet "${REGISTRY}/${REPO}:${t}"
done

# -------------------------------------------------------------- resultado
cor "==> Imagens publicadas"
aws ecr describe-images --repository-name "$REPO" --region "$REGIAO" \
  --query 'sort_by(imageDetails,&imagePushedAt)[-1].{tags:imageTags,push:imagePushedAt,mb:imageSizeInBytes}' \
  --output table

cor "==> Pronto. Para puxar de volta (rollback por tag):"
echo "    docker pull ${REGISTRY}/${REPO}:sha-${SHA_CURTO}"
