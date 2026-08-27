# Baseline para o AWS Academy Learner Lab

**Aluno:** José Henrique Teixeira Luiz — RA 3225002
**Executado em:** 27/08/2026
**Conta do lab:** `313438895454` · região `us-east-1`

Porte da infraestrutura da [`aula-04/`](../aula-04/) (VPC + EC2 Multi-AZ) para o
**AWS Academy Learner Lab**, depois que o professor migrou a disciplina para
esse ambiente ([commit `c56a0e5`](https://github.com/AleTavares/devops_20262/commit/c56a0e5)).

Não é uma entrega — é base validada para os próximos TFs, com as respostas das
perguntas que só a execução responde.

---

## O que muda em relação à `aula-04/`

A versão original foi feita em conta AWS própria e **não roda aqui sem ajuste**.

| `aula-04/` (conta própria) | `learner-lab-baseline/` | Por quê |
|---|---|---|
| `aws_iam_role` | removido | `voclabs` não cria entidades de IAM |
| `aws_iam_role_policy_attachment` | removido | idem |
| `aws_iam_instance_profile` | `data.aws_iam_instance_profile.lab` | usa o **LabInstanceProfile** pronto |
| `tls_private_key` + `aws_key_pair` | `key_name = "vockey"` | key pair já existe no lab |
| provider `tls` + `local` | removidos | não são mais necessários |

São **3 recursos IAM e 3 de chave a menos**: 18 recursos viraram 12.

O ganho de segurança do original continua: a EC2 recebe credencial temporária
via instance profile, sem access key em disco.

---

## Execução

Fluxo completo, com apply real e destroy imediato:

```
fmt → init → validate → plan → apply → curl + SSH → destroy
```

**Resultado:** `Apply complete! Resources: 12 added` →
`Destroy complete! Resources: 12 destroyed`. Conta verificada limpa ao final.

### Recursos criados

VPC `10.0.0.0/16` · 4 subnets (2 públicas + 2 privadas) em `us-east-1a` e
`us-east-1b` · Internet Gateway · route table + 2 associações · 2 security
groups · 1 EC2 `t3.micro` com a API subindo por User Data.

### API respondendo

```json
{"message":"TechNova API - Rodando na AWS!","aluno":"Jose Henrique Teixeira Luiz",
 "ra":"3225002","hostname":"ip-10-0-1-93.ec2.internal","uptime":"53 segundos"}
```

---

## As três perguntas que a execução respondeu

### 1. `t3.micro` é aceito ✅

Subiu sem reclamação. A restrição de tipo de instância da conta pessoal (que nos
obrigou a trocar `t2.micro` por `t3.micro`) **é da conta pessoal, não do lab** —
são limitações de origens diferentes que por acaso apontam para o mesmo tipo.

### 2. Criação de IAM é bloqueada ✅ (confirmado)

```
iam:ListRoles ....: PERMITIDO
iam:CreateUser ...: NEGADO
```

Leitura funciona, escrita não. É isso que inviabiliza portar o **TF-03** para cá
— aquele trabalho criou 19 recursos de IAM (2 grupos, 3 usuários, 4 policies,
1 role). Se um TF futuro pedir IAM, tem que ser na conta pessoal ou com a
`LabRole`.

### 3. ⚠️ A `LabRole` NÃO é de menor privilégio

Esta é a descoberta que mais importa, e ela contraria a evidência do TF-04.

Na `aula-04/` a role era construída à mão com uma única policy
(`AmazonS3ReadOnlyAccess`), e a evidência mais forte da entrega foi mostrar que
a instância **conseguia ler** o S3 e **era negada** no `s3:CreateBucket` —
menor privilégio demonstrado, não declarado.

**No Learner Lab isso não se reproduz.** A `LabRole` é ampla:

| Ação | Resultado |
|---|---|
| `s3:ListAllMyBuckets` | PERMITIDO |
| `ec2:DescribeInstances` | PERMITIDO |
| `iam:ListRoles` | PERMITIDO |
| `s3:CreateBucket` | **PERMITIDO** ← criou o bucket de verdade |

O teste de negação virou um bucket real, que foi removido em seguida.

**Consequência prática:** um TF que peça "demonstre menor privilégio" **não pode
usar a LabRole como evidência**. O lab entrega uma role permissiva de
conveniência; o exercício de menor privilégio exige criar a role, o que o lab
não deixa. Vale levantar com o professor se aparecer no enunciado.

---

## IMDSv2 obrigatório ✅

```
IMDSv1 (sem token) : HTTP 401 → bloqueado
IMDSv2 (com token) : i-0353b56d71667dad4 · us-east-1a
```

Bloqueia o SSRF clássico em que uma requisição forjada pela aplicação lê as
credenciais da role no endpoint de metadados.

> Nota de método: o primeiro teste usou `curl` sem `-f` e deu falso negativo —
> `curl` sai com código 0 mesmo em HTTP 401, então "IMDSv1 respondeu" era o
> teste errado, não a infra errada. O teste correto checa o status HTTP.

---

## Como usar

```bash
# 1. Atualizar as credenciais da sessão do lab
~/Cortex/Faculdade/DevOps/scripts/aws-lab-creds.sh

# 2. Subir
terraform init && terraform apply

# 3. Derrubar SEMPRE ao terminar
terraform destroy
```

As credenciais do lab expiram em ~4h. `ExpiredToken` significa reiniciar o lab e
recopiar, não bug no Terraform.

**Orçamento de USD 50 por aluno, e estourar apaga o ambiente e todo o
trabalho.** EC2 é desligada ao fim da sessão, mas **NAT Gateway e Load Balancer
continuam cobrando** — por isso o `destroy` aqui não é boa prática, é proteção.
