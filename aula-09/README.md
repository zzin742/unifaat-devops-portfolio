# Aula 09 — Amazon ECR e AI Review no CI/CD

[![AI Review](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/ai-review.yml/badge.svg)](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/ai-review.yml)
[![Security Scan](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/security-scan.yml/badge.svg)](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/security-scan.yml)

**Aluno:** José Henrique Teixeira Luiz · **RA:** 3225002

Pipeline que publica a imagem no **Amazon ECR** e revisa cada Pull Request
automaticamente, com um **quality gate** que bloqueia o merge quando acha algo
CRITICAL.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `ecr-push.sh` | cria o repositório ECR, autentica, builda e publica com tags |
| `Dockerfile` | multi-stage, usuário não-root, `tini` como PID 1, healthcheck |
| `.github/scripts/ai-review.js` | analisa o diff do PR contra **12 padrões** |
| `.github/workflows/ai-review.yml` | dispara em PR, comenta e aplica o gate |
| `.github/workflows/security-scan.yml` | `npm audit` + Trivy na imagem |
| `ia-cicd-analise.md` | a análise crítica pedida pelo TF |

## Como rodar

```bash
# 1. credenciais do Learner Lab (AWS Details -> Show), sempre us-east-1
export AWS_ACCESS_KEY_ID=...  AWS_SECRET_ACCESS_KEY=...  AWS_SESSION_TOKEN=...
export AWS_DEFAULT_REGION=us-east-1

# 2. publica sha-XXXXXXX e latest
./ecr-push.sh

# 3. publica também 1.2.3, 1.2 e 1
./ecr-push.sh v1.2.3

# 4. rollback por tag
docker pull <conta>.dkr.ecr.us-east-1.amazonaws.com/technova-api:sha-a3f91c2
```

## Tags publicadas

| Tag | Função |
|---|---|
| `sha-XXXXXXX` | rastreabilidade — aponta para um commit exato |
| `latest` | conveniência |
| `1.2.3`, `1.2`, `1` | contrato de versão (só com git tag `v*.*.*`) |

`latest` é mutável, então não serve para rollback nem auditoria. A tag de SHA é
a que permite voltar a um estado conhecido.

## Os 12 padrões do review

**🔴 CRITICAL** — secret hardcoded · access key AWS · chave privada · `eval()` ·
SQL injection · command injection

**🟡 WARNING** — `console.log` · `catch {}` vazio · bind em `0.0.0.0` ·
`http://` sem TLS

**🔵 INFO** — `TODO`/`FIXME`/`HACK` · imagem base `:latest`

Só CRITICAL bloqueia o merge. Se WARNING travasse, um `console.log` esquecido
teria o mesmo peso de uma credencial vazada — e um gate que reclama de tudo é um
gate que o time aprende a ignorar.

## Bônus implementados

| Bônus | Como |
|---|---|
| Lifecycle policy no ECR | expira `untagged` em 7 dias; mantém as 10 `sha-` mais recentes |
| Scan on push | `--image-scanning-configuration scanOnPush=true` na criação |
| Comentário atualizado | marca `<!-- ai-review-bot -->` e edita em vez de duplicar |
| Workflow de segurança | `security-scan.yml` separado, com cron semanal |
| Badges | os dois no topo deste README |
| Mais de 8 padrões | **12** |
| Dockerfile endurecido | multi-stage, não-root, `tini`, healthcheck, `.dockerignore` |

Detalhes e limitações em [`ia-cicd-analise.md`](ia-cicd-analise.md).
