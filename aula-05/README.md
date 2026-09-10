# Aula 05 — RDS e Remote State

**Aluno:** José Henrique Teixeira Luiz — **RA 3225002**
**Disciplina:** DevOps — UniFAAT 2026.2 — Prof. Alexandre Tavares
**Ambiente:** AWS Academy Learner Lab · `us-east-1`

Infraestrutura da TechNova com camada de dados persistente e state protegido:
VPC, RDS PostgreSQL em subnets privadas, EC2 na subnet pública conectando ao
banco, e o state do Terraform em S3 com lock no DynamoDB.

---

## Arquitetura

```
                        Internet
                            │
                    ┌───────▼────────┐
                    │ Internet GW    │
                    └───────┬────────┘
                            │
   ┌────────────────────────┼──────────────────────────┐
   │ VPC 10.0.0.0/16        │                          │
   │                        │                          │
   │   ┌────────────────────▼─────────────────┐        │
   │   │ subnet pública 10.0.1.0/24 · AZ-a    │        │
   │   │   ┌──────────────────────────────┐   │        │
   │   │   │ EC2 t2.micro                 │   │        │
   │   │   │ psql · IMDSv2 · LabRole      │   │        │
   │   │   └──────────────┬───────────────┘   │        │
   │   └──────────────────┼───────────────────┘        │
   │                      │ 5432                       │
   │        ┌─────────────▼──────────────┐             │
   │        │  SG do RDS: origem = SG    │             │
   │        │  da EC2, não o CIDR        │             │
   │        └─────────────┬──────────────┘             │
   │                      │                            │
   │   ┌──────────────────▼───────────┐  ┌───────────┐ │
   │   │ privada 10.0.10.0/24 · AZ-a  │  │ 10.0.11.0 │ │
   │   │      RDS PostgreSQL 15       │  │  · AZ-b   │ │
   │   │      db.t3.micro · cifrado   │  │           │ │
   │   └──────────────────────────────┘  └───────────┘ │
   │            └────── DB Subnet Group ──────┘        │
   │                                                   │
   │   sem rota para o IGW → sem saída para internet   │
   └───────────────────────────────────────────────────┘

   State:  S3 (versionado + cifrado + sem acesso público)
           DynamoDB (lock por LockID)
```

---

## Estrutura

```
aula-05/
├── backend/                 infra do state — roda PRIMEIRO, com state local
│   ├── main.tf              bucket S3 + tabela DynamoDB
│   └── outputs.tf           imprime o bloco de backend pronto para colar
├── providers.tf             backend "s3" + provider AWS
├── vpc.tf                   VPC, subnets, IGW, route table, DB subnet group
├── security-groups.tf       SG da EC2 e SG do RDS
├── rds.tf                   instância PostgreSQL
├── ec2.tf                   AMI, instance profile, instância
├── variables.tf             variáveis e tags comuns
├── outputs.tf               endpoints e evidências
├── user_data.sh             instala psql e testa alcance ao RDS
└── terraform.tfvars.example modelo — o real fica fora do Git
```

---

## Ordem de execução

O backend é um problema de ovo e galinha: ele cria o bucket onde o state dos
outros projetos vai morar, então ele mesmo usa **state local**. É a única
exceção consciente.

```bash
# 0. Credenciais da sessão do Learner Lab (expiram em ~4h)
~/Cortex/Faculdade/DevOps/scripts/aws-lab-creds.sh

# 1. Backend primeiro
cd backend/
terraform init && terraform apply
terraform output bloco_backend      # imprime o bloco pronto

# 2. Colar o nome do bucket em ../providers.tf

# 3. Infra principal
cd ..
cp terraform.tfvars.example terraform.tfvars   # e definir a senha
terraform init                                  # migra o state para o S3
terraform apply
```

---

## Decisões de projeto

### O banco é privado por dois mecanismos, não um

`publicly_accessible = false` tira o endereço público. Mas isso sozinho não
basta: as subnets privadas também **não têm rota para o Internet Gateway**.
Qualquer um dos dois sem o outro deixa uma brecha — o primeiro sem o segundo
ainda permitiria saída via NAT, e o segundo sem o primeiro exporia um endpoint
público inalcançável mas anunciado.

Não há NAT Gateway de propósito: ele custa por hora e **continua cobrando entre
as sessões do Learner Lab**, contra um orçamento de USD 50 que apaga o ambiente
inteiro se estourar. O RDS não precisa de saída para a internet.

### Security Group por identidade, não por endereço

*(Desafio extra 1)*

O enunciado aceita liberar a porta 5432 para o CIDR da VPC. Aqui a origem é o
**Security Group da EC2**:

```hcl
ingress {
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = [aws_security_group.ec2.id]   # não cidr_blocks
}
```

Pelo CIDR, qualquer recurso futuro dentro de `10.0.0.0/16` herdaria acesso ao
banco sem ninguém decidir isso. Pelo SG, só entra quem estiver explicitamente
naquele grupo. É o menor privilégio da aula 03 aplicado em rede: restringir
pela **identidade** da origem, não pelo endereço dela.

O SG do RDS também não tem regra de egress — o banco não inicia conexão com
ninguém.

### A senha nunca toca o disco nem o user data

*(Desafio extra 4, com ressalva)*

O desafio pede user data que instale o psql **e teste a conexão**, salvando em
log. O teste automático verifica **alcance de rede** até a 5432, não
autenticação:

```bash
timeout 10 bash -c "cat < /dev/null > /dev/tcp/${RDS_HOST}/5432"
```

Autenticar exigiria a senha dentro do user data — e o user data fica legível no
endpoint de metadados para qualquer processo rodando na instância. Trocar um
teste mais completo por vazamento de credencial não compensa.

O teste autenticado fica em `/usr/local/bin/testar-rds.sh`, rodado por SSH com a
senha vindo do ambiente:

```bash
PGPASSWORD='...' /usr/local/bin/testar-rds.sh
```

A variável `db_password` não tem valor default: sem definição, o Terraform para
e pergunta, em vez de subir um banco com credencial previsível.

### Instance profile: reusar, não criar

*(Desafio extra 3, adaptado ao ambiente)*

O desafio pede instance profile com permissão mínima. No Learner Lab a sessão
assume o papel `voclabs`, que **não cria entidades de IAM** — `iam:CreateUser`
retorna AccessDenied (verificado na prática).

O caminho é referenciar o `LabInstanceProfile` que o lab já entrega. O benefício
prático se mantém: a instância recebe credencial temporária pelo metadata
service, sem access key em disco.

⚠️ **Ressalva honesta:** a `LabRole` **não** é de menor privilégio. Ela permite
`s3:CreateBucket`, `ec2:Describe*` e `iam:List*`. No lab não há como entregar
uma role restrita, porque criar role é justamente o que ele bloqueia. Numa conta
própria — como na aula 03 — a role seria construída com a policy mínima.

### `for_each` em vez de `count` nas subnets

Com `count`, remover a primeira subnet renumera as seguintes e o Terraform
destrói e recria recursos que não mudaram. A chave do map é estável.

### Por que o bucket de state tem `force_destroy = true`

Parece contraditório num bucket que se quer proteger. O motivo é a limpeza do
laboratório: o versionamento mantém versões antigas, e um bucket versionado não
aceita `destroy` enquanto elas existirem — o `terraform destroy` do backend
falharia e deixaria recursos cobrando. Em produção seria `false`, com remoção
manual e deliberada.

---

## Segurança

| Item | Como |
|---|---|
| Senha do banco | `sensitive = true`, sem default, em `terraform.tfvars` fora do Git |
| Validação da senha | mínimo de 12 caracteres, via `validation` |
| Usuário master | bloqueia nomes reservados (`admin`, `postgres`, `root`) |
| RDS em repouso | `storage_encrypted = true` |
| State em repouso | SSE-AES256 no bucket |
| Bucket de state | versionado + Block Public Access nos 4 eixos |
| Concorrência | lock no DynamoDB por `LockID` |
| Metadados da EC2 | IMDSv2 obrigatório (`http_tokens = "required"`) |
| Volume raiz | criptografado |
| `.gitignore` | `.terraform/`, `*.tfstate*`, `terraform.tfvars`, `*.pem` |

---

## Limpeza

Recursos esquecidos consomem o orçamento do lab, e o RDS **não é desligado
automaticamente** entre sessões — diferente da EC2.

```bash
terraform destroy                          # infra principal
cd backend/
aws s3 rm s3://<bucket> --recursive        # esvaziar antes
terraform destroy                          # bucket + tabela
```
