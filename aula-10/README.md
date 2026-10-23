# Aula 10 — Terraform Automatizado e CD Pipelines

[![Terraform Plan](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/terraform-plan.yml/badge.svg)](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/terraform-plan.yml)
[![CD Pipeline](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/cd.yml/badge.svg)](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/cd.yml)

**Aluno:** José Henrique Teixeira Luiz · **RA:** 3225002

Dois fluxos automatizados: a infraestrutura muda por Pull Request, e o deploy
acontece sozinho no merge.

## Os dois fluxos

```
INFRAESTRUTURA                       APLICAÇÃO
abre PR com .tf                      merge na main
      ↓                                    ↓
terraform-plan.yml                     cd.yml
  fmt → init → validate → plan           lint → test
      ↓                                    ↓
comentário no PR                       build + push (ECR)
  (+ aviso se destrói)                     ↓
      ↓                                 deploy SSH (Recreate)
   merge                                   ↓
      ↓                                 health check
terraform-apply.yml                        ↓
  apply -auto-approve                  comentário no commit
```

## Arquivos

| Arquivo | O que faz |
|---|---|
| `technova-api/` | a aplicação e o Dockerfile (context do build) |
| `terraform/main.tf` | ECR + security group + EC2 com Docker |
| `terraform/provider.tf` | provider fixado em 5.31.0 (SCP do Lab) |
| `.github/workflows/terraform-plan.yml` | plan em PR, comentado no próprio PR |
| `.github/workflows/terraform-apply.yml` | apply no merge para a main |
| `.github/workflows/cd.yml` | lint → test → build-push → deploy → health check |
| `gitops-cd-analise.md` | a análise crítica pedida pelo TF |
| `docs/runbook-rollback.md` | procedimento de rollback |

> Os workflows que **executam** ficam na raiz do repositório
> (`.github/workflows/`), porque o GitHub Actions só reconhece workflows ali.
> As cópias em `aula-10/.github/workflows/` existem para atender à estrutura
> pedida no enunciado.

## Como reproduzir

### 1. Secrets no repositório

Learner Lab: **AWS Details → Show**, e cadastre em *Settings → Secrets → Actions*:

| Secret | De onde vem |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS Details |
| `AWS_SECRET_ACCESS_KEY` | AWS Details |
| `AWS_SESSION_TOKEN` | AWS Details |
| `EC2_SSH_KEY` | conteúdo do `labsuser.pem` |

> As três primeiras **expiram a cada sessão do Lab** e precisam ser
> reconfiguradas. É a limitação que o OIDC resolveria — ver `gitops-cd-analise.md`.

### 2. Criar a infraestrutura

Abra um PR mexendo em `aula-10/terraform/`: o plan aparece como comentário.
No merge, o apply roda sozinho.

Ou localmente:

```bash
cd aula-10/terraform
terraform init && terraform plan && terraform apply
terraform output health_url
```

### 3. Deploy

Qualquer push na main que toque `aula-10/` dispara o `cd.yml`. Para disparar à
mão: **Actions → CD Pipeline (Aula 10) → Run workflow**.

### 4. Conferir

```bash
curl http://<IP>:3000/health
```

### 5. Limpar (obrigatório)

```bash
cd aula-10/terraform && terraform destroy
```

## Bônus implementados

| Bônus | Como |
|---|---|
| Plan detecta destroy e exige aprovação | conta `resource_changes` com ação `delete`; se > 0, avisa no comentário e falha o check |
| Comentário atualizado, não duplicado | marca `<!-- terraform-plan-bot -->` e edita o existente |
| `terraform fmt -check` no plan | passo próprio, reportado na tabela do comentário |
| `GITHUB_SHA` no deploy | vai como env do container, para rastreabilidade |
| Notificação de deploy | comentário automático no commit, com imagem, host e resultado |
| Runbook de rollback | `docs/runbook-rollback.md`, testado conceitualmente passo a passo |

## Decisões que valem explicar

**O deploy descobre o IP sozinho**, via `aws ec2 describe-instances` filtrando
pela tag que o Terraform aplicou. Assim o pipeline não depende de alguém
atualizar um secret toda vez que a instância é recriada.

**O login no ECR vem antes do `docker pull`.** A imagem é privada: na ordem
inversa, o container antigo já teria sido removido e o pull falharia — deixando
nada no ar.

**`--provenance=false` no build.** Sem isso o buildx gera um *manifest list*
com atestação, e o scan do ECR não processa esse formato. Aprendi isso na
aula-09, onde o `scanOnPush` ficou sem resultado exatamente por esse motivo.

**O `concurrency` do apply e do deploy não cancela o que está em andamento.**
Apply interrompido no meio deixa recurso criado fora do state; deploy pela
metade é pior que deploy atrasado.
