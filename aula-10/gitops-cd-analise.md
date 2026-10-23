# GitOps e CD — análise

**Aluno:** José Henrique Teixeira Luiz · **RA:** 3225002

---

## 1. O fluxo GitOps: por que plan no PR e apply no merge

A regra do CTO — "nenhum humano executa Terraform diretamente" — não é sobre
desconfiar das pessoas. É sobre três problemas que o `terraform apply` rodado
na máquina de alguém cria:

| Problema | O que acontece |
|---|---|
| **Sem revisão** | a mudança vai para a nuvem sem ninguém além do autor ter visto |
| **Sem rastro** | não existe registro de quem aplicou o quê, nem quando |
| **Divergência** | a máquina de cada um tem uma versão de Terraform e um `.tfvars` diferente |

A separação em dois momentos resolve cada um:

**O plan no PR transforma a mudança de infraestrutura em algo revisável.** O
diff do Terraform não diz muito sozinho: `instance_type = "t3.micro"` virando
`"t3.large"` é uma linha, mas o plan mostra que isso **recria a instância**. É
a diferença entre revisar a intenção e revisar a consequência. Por isso o
comentário no PR não é enfeite — é o artefato que torna a revisão possível.

**O apply no merge garante que o que foi revisado é o que é aplicado.** Entre
aprovar o PR e a infraestrutura mudar não existe passo manual onde alguém possa
"ajustar uma coisinha". O merge é a autorização, e o pipeline é o único que
executa.

O efeito combinado é que **o repositório passa a ser a fonte da verdade**: para
saber como a infraestrutura está, lê-se o `.tf` da main, não o console da AWS.

### Um guardrail que achei necessário acrescentar

O plan comum não distingue "criar uma instância" de "destruir o banco de
dados" — os dois são só texto colorido. Adicionei uma contagem de recursos com
ação `delete`:

```
terraform show -json tfplan  →  conta resource_changes com 'delete'
                             →  se > 0, comentário com aviso + check vermelho
```

Destruição não é reversível pelo pipeline: o `terraform destroy` não tem
desfazer. Fazer o check falhar obriga alguém a olhar e aprovar conscientemente,
em vez de clicar em merge no automático.

---

## 2. Autenticação no Learner Lab, e por que ela não é o certo

O workflow autentica assim:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-session-token:     ${{ secrets.AWS_SESSION_TOKEN }}
```

As três credenciais temporárias da sessão, guardadas como GitHub Secrets.
**Funciona, mas não é o padrão de produção** — e vale ser explícito sobre o
porquê.

### O que seria o certo: OIDC + role IAM

```yaml
# Como seria FORA do Learner Lab:
permissions:
  id-token: write
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::<conta>:role/github-actions-technova
      aws-region: us-east-1
```

Com OIDC, o GitHub apresenta um token assinado por ele mesmo, e a AWS confia
nesse token através de um *identity provider* configurado na conta. A diferença
prática:

| | Credenciais como secret | OIDC + role |
|---|---|---|
| Existe chave guardada? | **sim**, nos secrets do repositório | **não** |
| Validade | expira na sessão, precisa ser renovada **na mão** | credencial de minutos, emitida a cada execução |
| Se o secret vazar | vale até expirar, em qualquer lugar | não há o que vazar |
| Escopo | o que a sessão do Lab permite | restrito por `sub` — branch e repositório específicos |

### Por que não dá no Lab

O Learner Lab **não permite criar OIDC provider nem roles IAM**. Sem poder
criar o provider (`iam:CreateOpenIDConnectProvider`) nem a role que o GitHub
assumiria, o caminho OIDC está fechado por política da organização — a mesma
restrição que me obrigou a usar a `LabRole` e o `LabInstanceProfile` prontos
em vez de criar um perfil para a instância.

### A consequência prática, que é chata e honesta

**As credenciais do Lab expiram a cada sessão.** Isso significa que, na prática,
os três secrets precisam ser reconfigurados toda vez que o lab é reiniciado,
senão os workflows falham com `ExpiredToken`. Um pipeline que depende de
intervenção manual recorrente não é automação de verdade — é automação com
muleta. É exatamente o problema que o OIDC resolve, e é por isso que ele é o
padrão fora do ambiente acadêmico.

---

## 3. A estratégia Recreate

```
stop  →  rm  →  pull  →  run
```

A aplicação **fica fora do ar** entre o `stop` e o momento em que o novo
container responde — alguns segundos, mas é indisponibilidade real.

| A favor | Contra |
|---|---|
| Simples: quatro comandos, nada para dar errado no meio | tem downtime, por menor que seja |
| Sem estado intermediário: ou é a versão nova, ou é a antiga | não há rollback automático se a nova versão subir quebrada |
| Não exige load balancer nem orquestrador | não dá para validar a nova versão antes de direcionar tráfego |
| Uma instância, um container — barato | não escala para múltiplas instâncias |

**Quando Recreate é a escolha certa:** ambiente de desenvolvimento ou
homologação; aplicação interna onde alguns segundos não custam nada; **e,
sobretudo, quando a versão nova não pode coexistir com a antiga** — por exemplo,
uma migração de banco incompatível, em que ter as duas versões rodando ao mesmo
tempo corromperia dados.

**Quando não serve:** qualquer coisa com usuário real esperando resposta. Aí
entram Rolling (substitui aos poucos), Blue-Green (sobe o ambiente paralelo e
vira o tráfego de uma vez) ou Canary (manda 5% do tráfego para a versão nova e
observa).

### A ordem dos passos no deploy, e por que ela importa

No `cd.yml`, o **login no ECR vem antes do pull** — e isso não é detalhe de
estilo. A imagem é privada. Se o login fosse depois, a sequência seria: remover
o container que funcionava, tentar puxar, falhar com `no basic auth
credentials`, e ficar **sem nada no ar**. Um erro de ordenação viraria uma
queda.

---

## 4. Continuous Delivery × Continuous Deployment

Os dois se abreviam CD e são confundidos o tempo todo. A diferença é **uma só**:
existe ou não um humano entre o pipeline e a produção.

| | Continuous **Delivery** | Continuous **Deployment** |
|---|---|---|
| Até onde o pipeline vai | deixa a versão **pronta** para ir | **coloca** em produção |
| Quem decide o momento | uma pessoa aprova | ninguém, é automático |
| Pressuposto | o teste automatizado é bom, mas não suficiente | o teste automatizado é a única rede |
| Típico em | setor regulado, release com data, produto com marketing atrelado | SaaS, time maduro, forte observabilidade |

**O que implementei aqui é Continuous Deployment**: o merge na main leva a
aplicação até a EC2 sem aprovação intermediária. Para virar Delivery bastaria
um passo — colocar o job `deploy` em um GitHub Environment com *protection
rule*, e o pipeline pararia ali esperando alguém clicar.

Essa é a parte interessante: **a diferença entre os dois é uma configuração,
não uma arquitetura**. O que muda é a resposta a "a gente confia nos testes o
bastante para dispensar o olho humano?" — e isso é decisão de time, não de
ferramenta.

---

## 5. Limitações identificadas

### O state do Terraform é local, e isso é um problema real

O `provider.tf` não configura backend remoto. Como o apply roda em um runner
efêmero do GitHub Actions, **cada execução começa sem state**. Na prática:

- o apply tenta **criar de novo** recursos que já existem, e falha com
  `AlreadyExists`;
- não há lock, então dois merges próximos poderiam aplicar em paralelo;
- `terraform destroy` pelo pipeline não funciona, porque não há state do que
  destruir.

O certo é **S3 + DynamoDB** para state e lock — que foi o que fiz na prova do
1º bimestre, com uma tabela de `LockID`. Não implementei aqui porque o bucket
de state precisaria sobreviver entre sessões do Lab, e o Learner Lab é
reiniciado com frequência. **Registro como dívida consciente, não como
esquecimento**: em um ambiente real este seria o primeiro item a corrigir, antes
de qualquer bônus.

### O SSH aceita conexão de qualquer IP

`ssh_cidr = "0.0.0.0/0"`. O motivo é que o runner do GitHub Actions não tem IP
fixo — a faixa muda e é enorme. As alternativas seriam usar **AWS Systems
Manager Session Manager** (sem porta 22 aberta, que foi o que usei na prova do
1º bimestre) ou um runner auto-hospedado com IP conhecido. Para um lab com
instância efêmera é aceitável; para produção, não seria.

### O health check valida que respondeu, não que funciona

O `/health` devolver `200` prova que o processo subiu e a porta está aberta.
**Não prova** que a aplicação conversa com o banco, que a versão é a esperada ou
que as rotas de negócio respondem. Um health check mais honesto verificaria as
dependências — e aí o deploy falharia nos casos em que hoje ele passa achando
que está tudo bem.

### Não há rollback automático

Se a versão nova subir quebrada de um jeito que o health check não pegue, o
pipeline termina verde e o problema fica no ar até alguém notar. O
[runbook de rollback](docs/runbook-rollback.md) cobre o procedimento manual,
mas o ideal seria o próprio pipeline detectar e voltar sozinho.

---

## 6. O que eu melhoraria, em ordem

1. **State remoto em S3 + DynamoDB.** Sem isso o GitOps de Terraform é
   decorativo — é o item que mais compromete o resto.
2. **OIDC em vez de credenciais em secret**, assim que o ambiente permitir.
   Elimina de uma vez a chave guardada e a renovação manual.
3. **SSM Session Manager no lugar do SSH**, fechando a porta 22.
4. **Health check que valide dependências**, não só o processo.
5. **Rollback automático** quando o health check falhar: guardar a tag anterior
   e, em caso de falha, subir de volta sem intervenção.
6. **GitHub Environment com approval** no job de deploy — vira Continuous
   Delivery com uma linha de configuração, se o time decidir que quer o olho
   humano antes da produção.
