# Runbook — Rollback de deploy (Aula 10)

**Quando usar:** o deploy entrou, o health check passou, mas a aplicação está
se comportando mal em produção — erro em rota específica, lentidão, regressão
de comportamento.

**Tempo estimado:** 2 a 3 minutos.

---

## Antes de começar: descubra para onde voltar

Toda imagem publicada tem uma tag `sha-XXXXXXX` que aponta para um commit
exato. É isso que torna o rollback possível — `latest` não serve, porque ele
muda de significado a cada deploy.

```bash
aws ecr describe-images \
  --repository-name technova-aula10-api \
  --region us-east-1 \
  --query 'sort_by(imageDetails,&imagePushedAt)[*].{tags:imageTags,quando:imagePushedAt}' \
  --output table
```

Anote a tag **anterior** à que está no ar.

Para confirmar o que está rodando agora:

```bash
ssh -i ~/.ssh/labsuser.pem ec2-user@<IP_DA_INSTANCIA> \
  'sudo docker ps --format "{{.Image}}"'
```

---

## O procedimento

### 1. Conecte na instância

```bash
ssh -i ~/.ssh/labsuser.pem ec2-user@<IP_DA_INSTANCIA>
```

O IP sai do Terraform (`terraform output instance_public_ip`) ou da AWS:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=technova-aula10-api" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

### 2. Faça login no ECR — **antes** do pull

Este é o passo que mais se esquece. A imagem é **privada**: sem o login, o
`docker pull` falha com `no basic auth credentials`, e o container antigo já
foi removido — ou seja, você fica sem nada no ar.

```bash
export AWS_DEFAULT_REGION=us-east-1
REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

aws ecr get-login-password --region us-east-1 \
  | sudo docker login --username AWS --password-stdin "$REGISTRY"
```

> No Learner Lab o token do ECR dura 12 horas e as credenciais da sessão
> expiram antes disso. Se o login falhar com `ExpiredToken`, pegue as
> credenciais novas em **AWS Details** e reexporte as três variáveis.

### 3. Puxe a versão anterior **antes** de derrubar a atual

Ordem importa. Puxar primeiro reduz a janela de indisponibilidade ao tempo de
reiniciar o container, em vez de incluir o tempo de download.

```bash
TAG_ANTERIOR=sha-a1b2c3d     # a que você anotou
sudo docker pull "$REGISTRY/technova-aula10-api:$TAG_ANTERIOR"
```

### 4. Recreate com a versão anterior

```bash
sudo docker stop  technova-api || true
sudo docker rm -f technova-api || true

sudo docker run -d \
  --name technova-api \
  --restart unless-stopped \
  -p 3000:3000 \
  "$REGISTRY/technova-aula10-api:$TAG_ANTERIOR"
```

### 5. Confirme

```bash
curl -fsS http://localhost:3000/health
sudo docker ps --format '{{.Names}} {{.Status}} {{.Image}}'
```

De fora da instância:

```bash
curl -fsS http://<IP_DA_INSTANCIA>:3000/health
```

---

## Depois do rollback

O rollback resolve o sintoma, não a causa. A main continua com o commit ruim,
então o **próximo merge vai reimplantar o problema**.

Reverta no Git:

```bash
git revert <sha-do-commit-ruim>
git push origin main
```

Isso dispara o `cd.yml`, que publica uma imagem nova sem a regressão. O
rollback manual é a ponte até esse momento, não o conserto.

---

## Alternativa: pelo próprio pipeline

Se o commit anterior ainda está na main, dá para refazer o deploy sem SSH
nenhum: **Actions → CD Pipeline (Aula 10) → Run workflow**, a partir do
commit desejado. É mais lento (refaz lint, test e build) mas deixa rastro no
histórico de execuções — e não depende de ninguém lembrar o procedimento.

---

## O que torna isso possível

| Decisão | Por quê |
|---|---|
| Tag `sha-XXXXXXX` em toda imagem | dá um nome estável a cada versão; `latest` é mutável e não serve para voltar |
| `image_tag_mutability = MUTABLE` só para `latest` | as tags de SHA nunca são reescritas |
| Lifecycle policy expira **apenas** imagens sem tag | as versões anteriores continuam disponíveis para rollback |
| `--restart unless-stopped` | a instância reiniciar não derruba a aplicação |
