# Infraestrutura TechNova — Aula 04

VPC Multi-AZ com EC2 provisionada por Terraform. 18 recursos: 1 VPC, 4 subnets
em 2 AZs, Internet Gateway, route table, 2 security groups, key pair, IAM role
com instance profile e uma instância rodando a API Node.js via User Data.

**Aluno:** José Henrique Teixeira Luiz — **RA:** 3225002

## Diagrama da Arquitetura

```
                              INTERNET
                                  │
                    ┌─────────────┴──────────────┐
                    │    Internet Gateway        │
                    │    technova-igw            │
                    └─────────────┬──────────────┘
                                  │
                    ┌─────────────┴──────────────┐
                    │  Route Table pública        │
                    │  0.0.0.0/0 → IGW            │
                    └──────┬──────────────┬───────┘
                           │              │
╔══════════════════════════╪══════════════╪═══════════════════════════════╗
║  VPC technova-vpc  10.0.0.0/16          │                               ║
║                          │              │                               ║
║   ┌──────────────────────┴───┐  ┌───────┴──────────────────┐            ║
║   │  AZ us-east-1a           │  │  AZ us-east-1b           │            ║
║   │                          │  │                          │            ║
║   │  ┌────────────────────┐  │  │  ┌────────────────────┐  │            ║
║   │  │ public-a           │  │  │  │ public-b           │  │  PÚBLICAS  ║
║   │  │ 10.0.1.0/24        │  │  │  │ 10.0.3.0/24        │  │  rota p/   ║
║   │  │                    │  │  │  │                    │  │  IGW       ║
║   │  │  ┌──────────────┐  │  │  │  │   (reservada p/    │  │            ║
║   │  │  │ EC2 t3.micro │  │  │  │  │    Load Balancer   │  │            ║
║   │  │  │ technova-api │  │  │  │  │    futuro)         │  │            ║
║   │  │  │ :3000 :22    │  │  │  │  │                    │  │            ║
║   │  │  └──────┬───────┘  │  │  │  └────────────────────┘  │            ║
║   │  └─────────┼──────────┘  │  │                          │            ║
║   │            │             │  │                          │            ║
║   │  ┌─────────┼──────────┐  │  │  ┌────────────────────┐  │            ║
║   │  │ private-a          │  │  │  │ private-b          │  │  PRIVADAS  ║
║   │  │ 10.0.2.0/24        │  │  │  │ 10.0.4.0/24        │  │  route     ║
║   │  │                    │  │  │  │                    │  │  table     ║
║   │  │  (Postgres futuro) │  │  │  │  (réplica futura)  │  │  padrão    ║
║   │  │  db-sg :5432       │  │  │  │                    │  │  sem saída ║
║   │  └────────────────────┘  │  │  └────────────────────┘  │            ║
║   └──────────────────────────┘  └──────────────────────────┘            ║
╚═════════════════════════════════════════════════════════════════════════╝
             │
             │ Instance Profile (credencial temporária)
             ▼
    ┌──────────────────────┐
    │ IAM Role             │
    │ AmazonS3ReadOnlyAccess│──────► S3 (somente leitura)
    └──────────────────────┘

  SECURITY GROUPS
  ┌─────────────────────────────┬──────────────────────────────────┐
  │ technova-api-sg             │ technova-db-sg                   │
  │  in : 22   ← 0.0.0.0/0      │  in : 5432 ← 10.0.0.0/16 apenas  │
  │  in : 3000 ← 0.0.0.0/0      │  out: tudo                       │
  │  out: tudo                  │                                  │
  └─────────────────────────────┴──────────────────────────────────┘
```

## Como Usar

### Pré-requisitos

| Ferramenta | Versão usada |
|---|---|
| Terraform | 1.15.8 |
| AWS CLI | 2.36.25 |
| Credenciais AWS | usuário IAM com permissão de EC2, VPC e IAM |

A chave SSH **não precisa existir antes**: o Terraform gera o par com
`tls_private_key`, envia a pública pra AWS e salva a privada em
`~/.ssh/technova-key.pem` com permissão `0400`.

### Executar

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

### Testar

```bash
# a API responde na porta 3000
curl $(terraform output -raw api_url)
curl $(terraform output -raw api_url)/health
curl $(terraform output -raw api_url)/orders

# SSH — o comando pronto sai como output
$(terraform output -raw ssh_command)
```

Dentro da instância, para confirmar que o Instance Profile funciona:

```bash
aws sts get-caller-identity   # devolve assumed-role, não usuário IAM
ls ~/.aws                     # não existe: nenhuma credencial em disco
systemctl status technova-api
```

### Destruir

```bash
terraform destroy
```

⚠️ Rode isso assim que capturar as evidências. Este projeto cabe no Free Tier,
mas recurso esquecido ligado é o que gera cobrança inesperada.

## Decisões Técnicas

### Por que Multi-AZ

Uma Availability Zone é um data center fisicamente separado. Concentrar tudo
numa AZ significa que uma falha de energia ou rede naquele prédio derruba a
aplicação inteira — e o SLA da AWS para EC2 só vale em configuração multi-AZ.

Aqui a instância roda em uma AZ só (é uma máquina apenas), mas **a rede já está
pronta** para duas: quando entrar um Load Balancer, ele exige subnets em pelo
menos duas AZs para ser criado. Deixar isso pronto agora evita refazer a VPC
depois — e refazer VPC em produção significa recriar tudo que está dentro dela.

### Por que separar subnet pública de privada

A diferença entre as duas **não é um atributo da subnet**: é o roteamento. A
pública está associada a uma route table com rota `0.0.0.0/0 → IGW`; a privada
usa a route table padrão, que só conhece a rota local `10.0.0.0/16`.

O ganho é isolamento por construção: um banco na subnet privada é inalcançável
da internet mesmo que alguém erre a configuração do security group. São duas
camadas independentes de defesa — roteamento e firewall — e é preciso furar as
duas para expor o dado.

### Por que sem NAT Gateway

Dar saída para internet às subnets privadas exigiria um NAT Gateway, que custa
cerca de **US$ 32/mês rodando 24/7** — é o recurso que mais gera conta
inesperada em ambiente de estudo. O enunciado especifica que as privadas usam a
route table padrão, então não há NAT. Consequência real: uma instância na
subnet privada não conseguiria baixar pacotes do `dnf`. Para este trabalho isso
não é limitação, já que nada roda lá ainda.

### Por que systemd em vez de `npm start &`

Processo iniciado em background pelo User Data morre quando o script termina e
não volta depois de um reboot. Com uma unit de systemd (`Restart=always`,
`enable`), a API sobe sozinha no boot e se recupera de queda. É a diferença
entre "funcionou no dia da entrega" e "funciona".

### Por que AMI por data source

ID de AMI muda por região e a cada release da Amazon. Fixar `ami-0abc123` no
código quebra em outra região e congela a imagem numa versão que vai ficando
sem patch de segurança. O `data "aws_ami"` com `most_recent = true` resolve a
mais atual no momento do apply.

### ⚠️ t2.micro → t3.micro

**O enunciado pede `t2.micro`. Este projeto usa `t3.micro`, e a razão é da
conta, não do código.**

A conta usada está no plano gratuito novo da AWS (créditos por 6 meses), que
restringe o `RunInstances` aos tipos marcados como *free-tier-eligible*. O
`t2.micro` saiu dessa lista. A tentativa retorna:

```
InvalidParameterCombination: The specified instance type is not eligible
for Free Tier. For a list of Free Tier instance types, run
'describe-instance-types' with the filter 'free-tier-eligible=true'.
```

Rodando o comando que a própria mensagem sugere:

```bash
$ aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true"
t3.micro   2 vCPU   1024 MiB   x86_64
t3.small   2 vCPU   2048 MiB   x86_64
t4g.micro  2 vCPU   1024 MiB   arm64
```

`t3.micro` é o equivalente direto: mesma 1 GiB de RAM e 2 vCPU, geração mais
nova. A variável `instance_type` tem `validation` restringindo aos tipos
elegíveis, para que uma alteração distraída não gere cobrança.

### IMDSv2 obrigatório

A instância força `http_tokens = "required"`. Sem isso, o endpoint de metadados
responde a qualquer requisição simples — e o ataque clássico de SSRF consegue
ler as credenciais da role fazendo a aplicação buscar
`http://169.254.169.254/`. Com IMDSv2 é preciso um PUT prévio para obter token,
o que quebra esse vetor.

## Recursos Criados

| # | Recurso | Nome | Função |
|---|---------|------|--------|
| 1 | `aws_vpc` | `technova-vpc` | Rede isolada `10.0.0.0/16`, DNS habilitado |
| 2-3 | `aws_subnet` (pública) | `public-a`, `public-b` | `10.0.1.0/24` e `10.0.3.0/24`, em 2 AZs, IP público automático |
| 4-5 | `aws_subnet` (privada) | `private-a`, `private-b` | `10.0.2.0/24` e `10.0.4.0/24`, sem rota externa |
| 6 | `aws_internet_gateway` | `technova-igw` | Saída da VPC para a internet |
| 7 | `aws_route_table` | `technova-rt-public` | Rota `0.0.0.0/0 → IGW` |
| 8-9 | `aws_route_table_association` | — | Liga a route table às duas subnets públicas |
| 10 | `aws_security_group` | `technova-api-sg` | Libera 22 e 3000 |
| 11 | `aws_security_group` | `technova-db-sg` | 5432 apenas de `10.0.0.0/16` |
| 12 | `tls_private_key` | — | Gera o par RSA 4096 localmente |
| 13 | `aws_key_pair` | `3225002-technova-key` | Envia só a chave pública à AWS |
| 14 | `local_sensitive_file` | — | Salva a privada em `~/.ssh` com `0400` |
| 15 | `aws_iam_role` | `3225002-technova-ec2-role-a04` | Role assumida pela EC2 |
| 16 | `aws_iam_role_policy_attachment` | — | Anexa `AmazonS3ReadOnlyAccess` |
| 17 | `aws_iam_instance_profile` | `3225002-technova-ec2-profile-a04` | Entrega a role à instância |
| 18 | `aws_instance` | `technova-api` | `t3.micro`, AL2023, User Data com Node 18 |

## Evidências

| Arquivo | Conteúdo |
|---|---|
| `evidencia-plan.txt` | `terraform plan` completo — 18 to add, 702 linhas |
| `evidencia-api.json` | `curl` em `/`, `/health` e `/orders` |
| `evidencia-ssh.txt` | Versões, `sts get-caller-identity`, teste de menor privilégio |

O `evidencia-ssh.txt` mostra o ponto mais importante do trabalho:

```
Arn: arn:aws:sts::065247282195:assumed-role/3225002-technova-ec2-role-a04/i-004a6aec37d889978

$ aws s3 mb s3://teste-negado-3225002
AccessDenied ... is not authorized to perform: s3:CreateBucket

$ ls ~/.aws
No such file or directory
```

A instância se autentica como **role assumida**, consegue **ler** o S3, é
**negada** ao tentar escrever, e **não tem nenhuma credencial gravada em
disco**. Menor privilégio demonstrado na prática, não só declarado.

`terraform destroy` executado após a captura: **18 destroyed**, conta verificada
sem EC2, VPC, key pair, security group, volume EBS ou Elastic IP remanescente.
