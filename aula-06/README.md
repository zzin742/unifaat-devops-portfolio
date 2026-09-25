# Aula 06 — Biblioteca de Módulos Terraform da TechNova

**Aluno:** José Henrique Teixeira Luiz — **RA:** 3225002
**Disciplina:** DevOps — Prof. Alexandre da Costa Tavares Jr — UniFAAT 2026.2

Biblioteca de quatro módulos Terraform reutilizáveis que provisionam um ambiente
completo — rede, firewall, aplicação e banco — a partir de uma única composição.
Dois ambientes (**dev** e **staging**) são criados pelos **mesmos módulos**,
mudando apenas o `terraform.tfvars`.

## 1. Visão geral

O problema que a biblioteca resolve: sem módulos, criar um segundo ambiente
significa copiar e colar o `main.tf` inteiro e trocar os CIDRs na mão — e a
partir daí os dois ambientes divergem a cada alteração. Aqui, `environments/dev`
e `environments/staging` têm o **`main.tf` byte a byte idêntico**; a diferença
inteira entre um ambiente e outro cabe no `terraform.tfvars`.

```bash
$ diff environments/dev/main.tf environments/staging/main.tf
$ echo $?
0
```

## 2. Arquitetura — dependências entre os módulos

```
                    ┌─────────────┐
                    │   vpc       │  VPC, IGW, subnets (for_each), route tables
                    └──┬───────┬──┘
              vpc_id   │       │   public_subnet_ids / private_subnet_ids
            ┌──────────┘       └──────────────┐
            ▼                                 │
    ┌───────────────┐                         │
    │  api_sg       │  22, 3000               │
    │ security-group│                         │
    └───┬───────┬───┘                         │
        │       │ sg_id                       │
        │       └──────────────┐              │
        │ sg_id                ▼              │
        │              ┌───────────────┐      │
        │              │  rds_sg       │ 5432 apenas do api_sg
        │              │ security-group│      │
        │              └───────┬───────┘      │
        │                      │ sg_id        │
        ▼                      ▼              ▼
┌───────────────┐      ┌──────────────────────────┐
│  api_server   │      │      database            │
│     ec2       │◄─────│        rds               │
└───────────────┘ db_host└──────────────────────────┘
  subnet pública          subnets privadas, 2 AZs
```

Nenhum `depends_on` é escrito à mão: a ordem de criação vem do encadeamento
`output → input`. O caso mais importante é o `rds_sg`, que recebe
`module.api_sg.sg_id` — a regra da porta 5432 não cita CIDR nenhum, ela autoriza
o **Security Group** da aplicação.

## 3. Módulos disponíveis

| Módulo | Descrição |
|--------|-----------|
| [`vpc`](modules/vpc/) | VPC com subnets dinâmicas via `for_each`, IGW e route tables |
| [`security-group`](modules/security-group/) | SG genérico; regras de ingress como lista de objetos |
| [`ec2`](modules/ec2/) | Instância reutilizável, AMI recebida como input, IMDSv2 obrigatório |
| [`rds`](modules/rds/) | DB Subnet Group + PostgreSQL em subnets privadas |

---

### Módulo `vpc`

**Descrição:** cria a VPC e suas subnets a partir de um **mapa**, usando
`for_each`. Subnets marcadas como `public` recebem IP público automático e rota
para o Internet Gateway; as `private` ficam numa route table sem rota
`0.0.0.0/0`.

**Inputs:**

| Nome | Tipo | Obrigatório | Default | Descrição |
|------|------|-------------|---------|-----------|
| `project_name` | string | Sim | — | Nome do projeto, compõe o padrão de nomes |
| `environment` | string | Sim | — | Ambiente (dev, staging, prod) |
| `vpc_cidr` | string | Sim | — | CIDR block da VPC |
| `subnets` | map(object({cidr, az, type})) | Sim | — | Mapa de subnets; `type` é `public` ou `private` |
| `tags` | map(string) | Não | `{}` | Tags adicionais |

**Outputs:**

| Nome | Descrição |
|------|-----------|
| `vpc_id` | ID da VPC criada |
| `vpc_cidr` | CIDR block da VPC |
| `public_subnet_ids` | Lista de IDs das subnets públicas |
| `private_subnet_ids` | Lista de IDs das subnets privadas |
| `subnet_ids_by_name` | Mapa nome lógico → ID |
| `internet_gateway_id` | ID do Internet Gateway |

**Exemplo de uso:**

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name = "technova"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"

  subnets = {
    "public-1a"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public" }
    "public-1b"  = { cidr = "10.0.2.0/24", az = "us-east-1b", type = "public" }
    "private-1a" = { cidr = "10.0.3.0/24", az = "us-east-1a", type = "private" }
    "private-1b" = { cidr = "10.0.4.0/24", az = "us-east-1b", type = "private" }
  }
}
```

> **Por que `for_each` e não `count`:** com `count`, as subnets ficam indexadas
> por posição (`[0]`, `[1]`, `[2]`). Remover a subnet do meio da lista renumera
> as seguintes, e o Terraform planeja **destruir e recriar** subnets que não
> mudaram. Com `for_each`, o endereço de cada recurso é a chave do mapa
> (`aws_subnet.esta["private-1a"]`) e permanece estável.

---

### Módulo `security-group`

**Descrição:** Security Group genérico. Serve para API, banco, bastion ou
qualquer outro papel — o que muda entre os usos é apenas a lista
`ingress_rules`. Cada regra libera **por CIDR** ou **por Security Group de
origem**, nunca os dois.

**Inputs:**

| Nome | Tipo | Obrigatório | Default | Descrição |
|------|------|-------------|---------|-----------|
| `name` | string | Sim | — | Nome do SG, sem o prefixo de projeto/ambiente |
| `description` | string | Não | `"Gerenciado pelo Terraform"` | Descrição exigida pela AWS |
| `project_name` | string | Sim | — | Nome do projeto |
| `environment` | string | Sim | — | Ambiente |
| `vpc_id` | string | Sim | — | VPC onde o SG é criado |
| `ingress_rules` | list(object) | Não | `[]` | Regras de entrada (ver abaixo) |
| `enable_default_egress` | bool | Não | `true` | Cria a regra de saída liberando tudo |
| `tags` | map(string) | Não | `{}` | Tags adicionais |

Formato de cada item de `ingress_rules`:

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `description` | string | Sim | Descrição da regra |
| `from_port` / `to_port` | number | Sim | Faixa de portas |
| `protocol` | string | Não (`"tcp"`) | Protocolo |
| `cidr_blocks` | list(string) | Um dos dois | Libera por bloco de IP |
| `source_security_group_id` | string | Um dos dois | Libera por SG de origem |

Uma `validation` no módulo recusa a regra que informe os dois campos ou nenhum.

**Outputs:**

| Nome | Descrição |
|------|-----------|
| `sg_id` | ID do Security Group |
| `sg_name` | Nome completo do SG |
| `sg_arn` | ARN do SG |

**Exemplo de uso — o banco aceitando só a aplicação:**

```hcl
module "rds_sg" {
  source = "../../modules/security-group"

  name         = "rds-sg"
  description  = "PostgreSQL acessivel apenas pela EC2 da API"
  project_name = "technova"
  environment  = "dev"
  vpc_id       = module.vpc.vpc_id

  ingress_rules = [
    {
      description              = "PostgreSQL a partir do SG da API"
      from_port                = 5432
      to_port                  = 5432
      source_security_group_id = module.api_sg.sg_id   # ← composição
    },
  ]

  enable_default_egress = false
}
```

---

### Módulo `ec2`

**Descrição:** instância EC2 reutilizável. A AMI entra como **input**, não como
data source interno — assim o módulo serve para Amazon Linux, Ubuntu ou uma AMI
própria, e quem escolhe é o ambiente.

**Inputs:**

| Nome | Tipo | Obrigatório | Default | Descrição |
|------|------|-------------|---------|-----------|
| `instance_name` | string | Sim | — | Nome lógico da instância |
| `project_name` | string | Sim | — | Nome do projeto |
| `environment` | string | Sim | — | Ambiente |
| `ami_id` | string | Sim | — | AMI da instância |
| `instance_type` | string | Não | `t2.micro` | Tipo da instância |
| `subnet_id` | string | Sim | — | Subnet onde sobe |
| `security_group_ids` | list(string) | Sim | — | Security Groups associados |
| `key_name` | string | Não | `vockey` | Key pair para SSH |
| `iam_instance_profile` | string | Não | `LabInstanceProfile` | Instance profile |
| `user_data` | string | Não | `null` | Script de bootstrap |
| `root_volume_size` | number | Não | `8` | Volume raiz em GB |
| `tags` | map(string) | Não | `{}` | Tags adicionais |

**Outputs:**

| Nome | Descrição |
|------|-----------|
| `instance_id` | ID da instância |
| `public_ip` | IP público |
| `private_ip` | IP privado |
| `public_dns` | DNS público |
| `availability_zone` | AZ em que subiu |

**Exemplo de uso:**

```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

module "api_server" {
  source = "../../modules/ec2"

  instance_name = "api"
  project_name  = "technova"
  environment   = "dev"

  ami_id             = data.aws_ami.amazon_linux_2023.id
  subnet_id          = module.vpc.public_subnet_ids[0]   # ← composição
  security_group_ids = [module.api_sg.sg_id]             # ← composição
}
```

---

### Módulo `rds`

**Descrição:** DB Subnet Group com as subnets privadas mais uma instância
PostgreSQL. Encriptado em repouso e sem endpoint público.

**Inputs:**

| Nome | Tipo | Obrigatório | Default | Descrição |
|------|------|-------------|---------|-----------|
| `project_name` | string | Sim | — | Nome do projeto |
| `environment` | string | Sim | — | Ambiente |
| `db_name` | string | Sim | — | Nome do database |
| `db_username` | string | Sim | — | Usuário master |
| `db_password` | string (sensitive) | Sim | — | Senha master |
| `subnet_ids` | list(string) | Sim | — | Subnets privadas (mínimo 2 AZs) |
| `security_group_ids` | list(string) | Sim | — | Security Groups do banco |
| `instance_class` | string | Não | `db.t3.micro` | Classe da instância |
| `engine_version` | string | Não | `16` | Versão major do PostgreSQL |
| `allocated_storage` | number | Não | `20` | Armazenamento em GB |
| `tags` | map(string) | Não | `{}` | Tags adicionais |

**Outputs:**

| Nome | Descrição |
|------|-----------|
| `db_endpoint` | Endpoint no formato `host:porta` |
| `db_host` | Apenas o host |
| `db_name` | Nome do database |
| `db_port` | Porta |
| `db_subnet_group_name` | DB Subnet Group usado |

**Exemplo de uso:**

```hcl
module "database" {
  source = "../../modules/rds"

  project_name = "technova"
  environment  = "dev"

  db_name     = "technova_dev"
  db_username = "technova_app"
  db_password = var.db_password        # TF_VAR_db_password

  subnet_ids         = module.vpc.private_subnet_ids   # ← composição
  security_group_ids = [module.rds_sg.sg_id]           # ← composição
}
```

## 4. Como usar — criando um ambiente novo

```bash
cp -r environments/dev environments/prod
```

Depois basta editar `environments/prod/terraform.tfvars`:

```hcl
environment = "prod"
vpc_cidr    = "10.2.0.0/16"

subnets = {
  "public-1a"  = { cidr = "10.2.1.0/24", az = "us-east-1a", type = "public" }
  "public-1b"  = { cidr = "10.2.2.0/24", az = "us-east-1b", type = "public" }
  "private-1a" = { cidr = "10.2.3.0/24", az = "us-east-1a", type = "private" }
  "private-1b" = { cidr = "10.2.4.0/24", az = "us-east-1b", type = "private" }
}

db_name = "technova_prod"
```

Nenhuma linha de `main.tf` é tocada.

## 5. Pré-requisitos

| Item | Detalhe |
|------|---------|
| Terraform | >= 1.5.0 (o módulo usa `optional()` em `object`) |
| AWS CLI | configurado com as credenciais do Learner Lab |
| Ambiente AWS | **AWS Academy Learner Lab**, região `us-east-1` |
| Key pair | `vockey`, fornecida pelo Lab |
| Instance profile | `LabInstanceProfile`, fornecido pelo Lab |

O Lab entrega credenciais **temporárias** com Session Token, em
**AWS Details → AWS CLI**. Elas expiram com a sessão de 4 horas.

## 6. Como validar

```bash
export TF_VAR_db_password='SenhaForte123'    # senha nunca vai para o código

cd environments/dev
terraform init
terraform validate
terraform plan

cd ../staging
terraform init
terraform validate
terraform plan
```

Evidências capturadas em [`evidencias/`](evidencias/).

## 7. Decisões de projeto

- **Sem NAT Gateway.** O RDS não precisa de saída para a internet e o NAT
  custaria crédito do Learner Lab 24 h por dia sem entregar nada a esta
  arquitetura. A route table privada existe, mas sem rota `0.0.0.0/0`.
- **Sem IAM criado.** O Lab nega `iam:CreateRole`; a EC2 usa o
  `LabInstanceProfile` já existente.
- **IMDSv2 obrigatório** (`http_tokens = "required"`). Com o IMDSv1 aberto, um
  SSRF na aplicação leria as credenciais da role com um `GET` simples no
  endpoint de metadados.
- **Regras de SG em recursos separados**
  (`aws_vpc_security_group_ingress_rule`) em vez de blocos `ingress` inline:
  alterar uma regra passa a ser um diff de uma linha, não a recriação do SG
  inteiro e de tudo que depende dele.
- **`backup_retention_period = 0` e `skip_final_snapshot = true`** são
  aceitáveis **porque é ambiente descartável de laboratório**, como o enunciado
  pede. Em produção seriam o oposto.
- **State local.** O backend remoto foi o tema da aula 05 e já está entregue
  ali; aqui o foco é a biblioteca de módulos. Num ambiente real, cada
  `environment` teria seu próprio `backend "s3"` com `key` distinta, para dev e
  staging nunca compartilharem state.
