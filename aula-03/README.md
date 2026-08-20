# Aula 03 — Terraform + IAM | José Henrique Teixeira Luiz (RA 3225002)

Estrutura IAM completa da TechNova provisionada como código: 2 groups, 3 users,
4 custom policies e 1 service role com instance profile.

## Design da Estrutura IAM

### Por que dois grupos, e não permissão direta no usuário

A AWS permite anexar policy direto no user, e é justamente o que eu evitei. O
motivo é operacional: permissão presa ao usuário morre com ele. Quando alguém
entra no time, você refaz tudo na mão; quando sai, sobra permissão órfã que
ninguém lembra de remover.

Com grupo, a permissão descreve **um papel**, não uma pessoa. Trocar alguém de
função é mudar uma linha de membership. As policies não são tocadas.

Os dois grupos separam responsabilidades bem diferentes:

| Grupo | Quem é | O que precisa |
|---|---|---|
| `developers` | quem escreve código da aplicação | ler dados do S3 pra desenvolver e depurar |
| `platform-eng` | quem cuida da infraestrutura | ligar/desligar EC2 e escrever no S3 |

Um dev não precisa parar uma instância. Um engenheiro de plataforma precisa.
Misturar os dois num grupo só significaria dar a todo mundo o maior privilégio
do conjunto.

### O caso do Rafael: grupos se somam

O `rafael-platform` está nos **dois** grupos, e isso é intencional. Ele é
engenheiro de plataforma mas também mexe no código. Como as permissões da AWS
são cumulativas, ele acumula a leitura de S3 do primeiro grupo com a gestão de
EC2 do segundo — sem que eu precise criar um terceiro grupo "platform que
também é dev".

### O caso do Lucas: Deny para restringir dentro do grupo

O estagiário está em `developers`, mas não deveria poder escrever nada. Eu tinha
duas opções:

1. criar um grupo `developers-readonly` quase idêntico ao original
2. deixá-lo no grupo normal e negar explicitamente o que ele não pode

Escolhi a segunda. Um grupo duplicado vira dívida técnica: toda vez que a policy
de developers mudar, alguém precisa lembrar de replicar no gêmeo — e um dia não
lembra. Com uma policy inline de `Deny`, o Lucas herda tudo que o time herda e
mesmo assim não escreve, porque **Deny sempre vence Allow** na avaliação da AWS.

## Princípio do Menor Privilégio

Dar a cada identidade **exatamente** as permissões necessárias para a tarefa
dela — nem uma ação a mais, nem um recurso a mais — e nada além do tempo
necessário.

O detalhe que eu não tinha entendido antes desta aula é que menor privilégio tem
**dois eixos independentes**. Não basta restringir a ação: é preciso restringir
também sobre *o quê* ela pode agir. `s3:GetObject` em `Resource: "*"` continua
sendo leitura irrestrita de toda a conta.

### Exemplo 1 — restringindo o recurso, não só a ação

Na policy `s3-read` eu poderia ter escrito `Resource = "*"`. Em vez disso:

```hcl
Resource = ["arn:aws:s3:::technova-*/*"]
```

Se amanhã o RH criar um bucket `rh-folha-pagamento` nessa mesma conta, o time de
desenvolvimento simplesmente não o enxerga. Não é uma regra de processo que
alguém pode esquecer — é impossível pelo IAM.

Detalhe que me custou tempo: `ListBucket` age sobre o **bucket**
(`arn:aws:s3:::technova-*`) e `GetObject` age sobre o **objeto**
(`arn:aws:s3:::technova-*/*`). Usar o mesmo ARN nos dois faz uma das duas falhar
silenciosamente.

### Exemplo 2 — Condition amarrando permissão a tag

Na `ec2-s3-full`, o Start/Stop não vale pra qualquer instância:

```hcl
Condition = {
  StringEquals = {
    "aws:ResourceTag/Project" = "TechNova"
  }
}
```

A permissão passa a depender do **estado do recurso**, não do nome dele. Se
outro time subir uma EC2 na mesma conta sem essa tag, o platform-eng da TechNova
não consegue desligá-la nem por acidente. E o inverso também vale: uma instância
nova do projeto já nasce coberta, sem ninguém editar policy.

### E se eu usasse `AmazonS3FullAccess`?

Funcionaria. É exatamente por isso que é perigoso — o trabalho terminaria e nada
daria errado no dia da entrega.

O que essa policy gerenciada concede, na prática:

- `s3:*` em **todos** os buckets da conta, inclusive os que ainda não existem
- `s3:DeleteBucket` — um estagiário apaga a produção com um comando
- `s3:PutBucketPolicy` — alguém torna um bucket público sem passar por revisão
- `s3:PutBucketAcl` — abre dados pra internet inteira

Três consequências concretas:

1. **O raio de explosão vira a conta toda.** Uma credencial vazada de qualquer
   dev passa a valer por todos os dados da empresa, não só pelos do projeto.
2. **A auditoria perde sentido.** Perguntar "quem pode apagar este bucket?" tem
   como resposta "todo mundo com S3FullAccess" — o que não ajuda ninguém.
3. **Não há caminho de volta.** Tirar permissão que já existe quebra o trabalho
   de alguém, então na prática ninguém tira. Permissão excessiva só cresce.

A `deny-destructive` existe justamente como seguro contra esse cenário: mesmo
que alguém anexe `AmazonS3FullAccess` ao grupo amanhã, `DeleteBucket` continua
bloqueado, porque o Deny explícito prevalece.

## Diagrama de Permissões

```
PESSOAS
                                                    ┌──────────────────────┐
  juliana-dev ────────┐                        ┌───►│ s3-read              │
                      │                        │    │ Get/List technova-*  │
  lucas-intern ───────┼──► [ developers ] ─────┤    └──────────────────────┘
       │              │                        │    ┌──────────────────────┐
       │              │                        └───►│ deny-destructive     │
       │              │                             │ Deny Delete*/Terminate│
       │              │                             └──────────────────────┘
       │              │
       │              └──────────────────────┐
       │                                     │
  rafael-platform ──► [ platform-eng ] ──────┼───► ┌──────────────────────┐
                                             │     │ ec2-s3-full          │
                                             │     │ Start/Stop c/ tag    │
                                             │     │ S3 read+write        │
                                             │     └──────────────────────┘
       │
       └──► policy inline (Deny escrita) ──── vence o Allow herdado do grupo


SERVIÇO
  ┌───────────┐   assume    ┌──────────────┐   attach   ┌──────────────────┐
  │    EC2    │────────────►│  ec2-role    │───────────►│ ec2-app-data     │
  │ instância │             │ trust:       │            │ Get/Put em       │
  └───────────┘             │ ec2.amazonaws│            │ technova-app-    │
        ▲                   └──────────────┘            │ data-*           │
        │                                               └──────────────────┘
        │ iam_instance_profile                                   │
  ┌─────┴────────────┐                                           ▼
  │ ec2-profile      │                                    ┌─────────────┐
  │ (instance profile)│                                   │     S3      │
  └──────────────────┘                                    └─────────────┘

  Credencial temporária, rotacionada pela AWS. Nenhuma access key em disco.
```

## Comandos Utilizados

```bash
terraform init      # baixa o provider hashicorp/aws ~> 5.0
terraform fmt       # normaliza a formatação dos .tf
terraform validate  # checa sintaxe e referências, sem tocar na AWS
terraform plan      # mostra o que seria criado (evidência da entrega)
terraform apply     # cria de fato
terraform destroy   # remove tudo após capturar a evidência
```

## Reflexão — Console AWS vs Terraform

Fiz IAM pelo Console em outra ocasião e a diferença mais óbvia é a velocidade:
clicar é mais rápido **na primeira vez**. Só que o custo aparece depois.

**Auditoria.** No Console, a pergunta "por que este usuário tem essa permissão?"
não tem resposta. O CloudTrail diz *quem* clicou e *quando*, nunca *por quê*.
Aqui, `git log` mostra o commit, a mensagem e o PR. A justificativa fica junto do
código.

**Repetibilidade.** Reproduzir esta estrutura num ambiente de homologação pelo
Console significa repetir dezenas de cliques na mesma ordem, e alguma diferença
vai escapar. Com Terraform é `terraform apply` numa pasta nova. As duas contas
ficam idênticas por construção, não por disciplina de quem clicou.

**Revisão antes do dano.** O `terraform plan` é o que mais mudou minha cabeça:
dá pra ver a policy inteira **antes** de existir, e um colega pode revisar o
diff no PR. No Console, revisão só existe depois — quando a permissão já está
valendo.

**Remoção completa.** Excluir um user pelo Console deixa rastro: a policy órfã,
o membership, o instance profile que ninguém lembra. `terraform destroy` remove
o que o state conhece, e o state conhece tudo que foi criado.

Onde o Console ainda ganha: explorar um serviço que você não conhece, ou
investigar um incidente às duas da manhã. Aprender IAM clicando é mais rápido
que aprender lendo documentação de ARN.

Minha conclusão é que os dois convivem — **Console pra descobrir, Terraform pra
manter.** O erro é usar o Console pra manter, porque aí a infraestrutura real e
a documentada divergem, e a documentada vira ficção.

## Estrutura dos Arquivos

| Arquivo | Conteúdo |
|---|---|
| `providers.tf` | provider AWS `~> 5.0`, região `us-east-1` |
| `variables.tf` | variáveis + `locals` com prefixo de RA e tags comuns |
| `main.tf` | 2 groups, 3 users, memberships, policy inline do estagiário |
| `policies.tf` | 3 custom policies + attachments nos grupos |
| `roles.tf` | trust policy, service role, policy de dados, instance profile |
| `outputs.tf` | ARNs de users, groups, policies, role e nome do profile |
| `.gitignore` | bloqueia `.tfstate`, `.terraform/`, `*.tfvars` e chaves |
| `terraform-plan-output.txt` | evidência do `terraform plan` |

## Observações Técnicas

**Grupos IAM não aceitam tags.** É limitação da própria API da AWS — `aws_iam_group`
não expõe o argumento `tags`. Users, roles, policies e instance profiles recebem
as tags obrigatórias normalmente.

**Prefixo de RA em tudo.** Nome de recurso IAM é único por conta, e a turma
compartilha a mesma. Sem o `3225002-` na frente, o `apply` de dois alunos
colidiria.

**`max_session_duration` de 1h na role.** É o padrão, mas deixei explícito
porque é uma decisão de segurança: credencial temporária capturada expira em uma
hora sem ninguém fazer nada.
