# Aula 08 — CI Pipeline com GitHub Actions

[![CI Aula 08](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)](https://github.com/zzin742/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml)

**Aluno:** José Henrique Teixeira Luiz · **RA:** 3225002

Pipeline de integração contínua para a **TechNova API**, com três estágios
encadeados e cinco itens bônus.

## O pipeline

```
lint (ESLint)  →  test (Jest · Node 18 e 20)  →  build (Docker + smoke test)
                                                          ↓
                                              comentário automático no PR
```

A ordem é econômica, não estética: o lint leva ~10s e o build Docker leva
minutos. Falhar cedo custa menos.

## Requisitos obrigatórios

| # | Requisito | Onde está |
|---|---|---|
| R1 | Workflow multi-stage com `needs` | `.github/workflows/ci-aula08.yml` |
| R2 | ESLint com `semi`, `quotes`, `no-unused-vars` | `.eslintrc.json` |
| R3 | 9 testes Jest com coverage | `__tests__/server.test.js` |
| R4 | Docker build taggeado com o SHA | job `build` |
| R5 | Secret `AWS_REGION` referenciado | job `build` |
| R6 | Badge de status | topo deste README |
| R7 | Screenshots | `screenshots/` |

## Bônus implementados

| # | Bônus | Como |
|---|---|---|
| B1 | Matrix strategy | testes em Node 18 e 20, `fail-fast: false` |
| B2 | Cache de dependências | `setup-node` com `cache: npm` |
| B3 | Comentário no PR | job `comentar-no-pr` com `github-script` |
| B4 | Concurrency control | cancela execuções anteriores do mesmo ref |
| B5 | Smoke test no Docker | sobe o container, bate no `/health`, remove |

## Resultado local

```
ESLint     sem erros
Jest       9 passed, 9 total · 89.28% de cobertura
Docker     build ok
/health    {"status":"ok","version":"1.0.0"}
```

## Nota sobre a localização do workflow

O TF sugere `aula-08/.github/workflows/`. Mantive uma cópia ali pela estrutura,
mas **o workflow que executa está na raiz** do repositório — o GitHub Actions só
reconhece workflows em `.github/workflows/` da raiz. Os jobs usam
`working-directory: aula-08`.

## Como rodar localmente

```bash
cd aula-08
npm ci
npm run lint
npm test
docker build -t technova-api:local .
docker run -d --name tn -p 3000:3000 technova-api:local
curl http://localhost:3000/health
docker rm -f tn
```
