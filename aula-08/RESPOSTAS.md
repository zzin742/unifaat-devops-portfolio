# Respostas — TF Aula 08: GitHub Actions e CI Pipelines

**Aluno:** José Henrique Teixeira Luiz
**RA:** 3225002

---

## Questão 1 — O que dispara a execução de um workflow?

**Resposta: b)** Eventos configurados no campo `on:` do YAML, como `push`,
`pull_request` ou `workflow_dispatch`.

O `on:` é o contrato entre o repositório e o workflow: ele declara **a que o
workflow reage**. No pipeline desta entrega eu uso três gatilhos, cada um com um
propósito diferente:

```yaml
on:
  push:
    branches: [main]        # valida o que já entrou na main
  pull_request:             # valida ANTES de entrar
  workflow_dispatch:        # permite disparar na mão, pela aba Actions
```

Também usei o filtro `paths:` para o CI só rodar quando algo em `aula-08/` ou o
próprio workflow mudar — sem isso, alterar um README de outra aula gastaria
minutos de runner à toa.

**Por que as outras estão erradas:** a alternativa **a** descreve `schedule`
(cron), que existe mas **não é automático** — precisa ser declarado no `on:`. A
**c** descreve só o `workflow_dispatch`, que é um gatilho entre vários. A **d**
inventa uma restrição de permissão que não existe.

---

## Questão 2 — Qual a função da keyword `needs`?

**Resposta: c)** Cria dependência entre jobs — o job só executa se os jobs
listados em `needs` terminarem com sucesso.

Por padrão **todos os jobs rodam em paralelo**. O `needs` é o que transforma
jobs soltos em um pipeline com ordem. No meu workflow:

```
lint  →  test (Node 18 e 20)  →  build (Docker + smoke test)
```

A ordem não é estética, é econômica: o lint leva ~10 segundos e o build Docker
leva minutos. Rodar o lint primeiro significa que um ponto e vírgula faltando
derruba o pipeline em 10s em vez de 3 minutos.

Um detalhe que aprendi montando o job de comentário no PR: `needs` **sozinho**
cancela o job quando um dependente falha. Como eu quero comentar o resultado
*inclusive quando falha*, precisei combinar com `if: always()`.

**Por que as outras estão erradas:** **a** confunde com `secrets`/`env`; **b**
confunde com `runs-on`; **d** descreve retry, que no GitHub Actions nem existe
nativamente por job.

---

## Questão 3 — Onde armazenar credenciais AWS?

**Resposta: c)** Em GitHub Secrets (Settings → Secrets and variables →
Actions), referenciadas com `${{ secrets.NOME }}`.

Secrets ficam criptografados, **não aparecem nos logs** (o GitHub mascara o
valor automaticamente, trocando por `***`) e não são expostos para workflows
disparados por forks. No meu build eu referencio assim:

```yaml
env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
```

E confirmo o recebimento sem vazar nada, imprimindo o tamanho da string em vez
do valor bruto.

**Por que as outras estão erradas — e a `a` é perigosa:** commitar `.env` é o
erro clássico; o GitHub **não** mascara nada que esteja no repositório, e uma
vez no histórico do Git a credencial precisa ser rotacionada, não basta apagar o
arquivo. A **b** não faz sentido: `runs-on` escolhe o sistema operacional do
runner. A **d** descreve um campo que não existe.

---

## Questão 4 — Para que servem environments com approval gates?

**Resposta: b)** Garantir que deploys para ambientes sensíveis, como produção,
exijam aprovação humana antes de executar.

É o ponto em que a automação **para de propósito**. O pipeline builda, testa e
empacota sozinho, mas antes de tocar em produção ele aguarda um clique de quem
tem responsabilidade sobre aquilo. Além da aprovação, o environment permite
escopar secrets (a chave de produção só existe no environment de produção) e
restringir quais branches podem chegar nele.

**Por que as outras estão erradas:** **a** é o oposto — o gate deliberadamente
*atrasa* o pipeline; paralelismo é o padrão e o `needs` é que serializa. A **c**
é o contrário do propósito de um secret. A **d** descreve replicação de
repositório, que não tem relação.

---

## Observação sobre a estrutura da entrega

O TF sugere criar `aula-08/.github/workflows/`. Mantive uma cópia ali para
seguir a estrutura pedida, **mas o workflow que realmente executa está na raiz
do repositório** (`.github/workflows/ci-aula08.yml`), porque o GitHub Actions só
reconhece workflows em `.github/workflows/` da raiz. Os jobs usam
`working-directory: aula-08` para operar sobre o código desta aula.
