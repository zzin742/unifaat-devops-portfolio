# Aula 01 — Fundamentos de Git e Docker

## O que aprendi

**Git:**
- Sistema de controle de versão distribuído — cada dev tem a cópia completa do histórico, o que dá pra trabalhar offline e faz commit ser instantâneo.
- Workflow com branches (feature → merge) — separei o desenvolvimento da aplicação (`feature/aula-01-app`) da `main` pra manter a linha principal sempre estável. Só faço merge quando a feature tá pronta.
- Conventional Commits (`feat:`, `docs:`, `fix:`, `chore:`) — facilita ler o histórico e é o padrão que ferramentas de release notes automáticas leem.
- `.gitignore` — não commitar `node_modules/`, `.env` e outros artefatos poupa MB, evita conflito e não vaza segredo.
- `git log --oneline` — visão rápida do histórico, ótimo pra revisar antes de pedir merge/PR.

**Docker:**
- Container ≠ VM — container compartilha o kernel do host, então é muito mais leve e sobe em segundos. VM emula hardware completo.
- Dockerfile é uma receita passo a passo — cada `RUN`, `COPY`, `CMD` vira uma camada imutável em cache. Ordem importa pra reaproveitar cache no rebuild.
- Escolher a **imagem base certa** (`node:20-alpine` em vez de `node:20`) reduz de ~1GB pra ~50MB.
- `--production` no `npm install` evita instalar `devDependencies` no runtime — imagem menor e mais segura.
- `.dockerignore` evita mandar `node_modules/` e `.git/` pra dentro do build context — build mais rápido e imagem mais enxuta.

## Comandos Git praticados

- `git init -b main` — inicializa o repo já com branch `main`.
- `git add <arquivo>` — adiciona arquivo ao staging area.
- `git commit -m "..."` — cria commit com mensagem.
- `git checkout -b feature/aula-01-app` — cria e muda pra nova branch.
- `git checkout main` — volta pra branch principal.
- `git merge feature/aula-01-app` — traz os commits da feature pra `main`.
- `git log --oneline` — histórico compacto.
- `git remote add origin <url>` — conecta repo local ao GitHub.
- `git push -u origin main` — envia commits pro GitHub e configura tracking.

## Comandos Docker praticados

- `docker build -t portfolio-aula01:1.0 .` — constrói imagem com tag a partir do Dockerfile no diretório atual.
- `docker run -d --name portfolio-test -p 3000:3000 portfolio-aula01:1.0` — sobe o container em background mapeando porta 3000.
- `docker ps` — lista containers em execução.
- `docker logs portfolio-test` — mostra os logs do container.
- `docker stop portfolio-test` — para o container graciosamente.
- `docker rm portfolio-test` — remove o container parado.

## Como executar este container

```bash
cd aula-01/app
docker build -t portfolio-aula01:1.0 .
docker run -d -p 3000:3000 portfolio-aula01:1.0
curl http://localhost:3000
curl http://localhost:3000/health
```

## Dificuldades encontradas

- **Docker Desktop parado no primeiro build** — Docker CLI estava instalado mas o daemon não estava rodando. Resolvi abrindo o Docker Desktop pelo menu Iniciar e aguardando o ícone da bandeja ficar verde antes de rodar `docker build`.
- **Manter os arquivos Docker num commit separado** — precisei prestar atenção pra fazer o `git add` seletivo (`Dockerfile` e `.dockerignore` num commit e não junto com a aplicação) pra o histórico do Git contar a história direito.
- **Escolha da tag da imagem base** — inicialmente ia usar `node:20`, mas descobri que `node:20-alpine` é bem menor (Alpine Linux). Tradeoff: Alpine usa `musl` em vez de `glibc`, então algumas libs nativas podem ter compatibilidade menor — mas pra Express puro funciona liso.
