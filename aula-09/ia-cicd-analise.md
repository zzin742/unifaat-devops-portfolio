# IA no CI/CD — análise

**Aluno:** José Henrique Teixeira Luiz · **RA:** 3225002

---

## 1. Por que Amazon ECR, e não ghcr.io ou Docker Hub

A escolha aqui não foi de preferência técnica: foi **imposta pelo ambiente**, e
vale registrar isso com honestidade.

| Registry | Por que serviria | Por que não neste caso |
|---|---|---|
| **Docker Hub** | o mais conhecido | limite de *pulls* por IP na conta gratuita; repositório privado é pago |
| **ghcr.io** | integra com o GitHub sem credencial extra | exige um Personal Access Token com `write:packages` — fora do escopo do Learner Lab |
| **Amazon ECR** | fica **dentro da conta AWS** onde a infra já roda | a autenticação depende de credenciais que expiram a cada sessão |

O argumento decisivo é de **proximidade**: se a aplicação roda em EC2 ou ECS
dentro da AWS, puxar a imagem do ECR mantém o tráfego dentro da rede da própria
nuvem. Não sai pela internet, não paga egress e a permissão é a mesma do IAM que
já governa o resto.

### As restrições reais do Learner Lab

Três coisas moldaram o desenho do script:

1. **Não dá para criar usuários, grupos ou roles IAM.** O caminho normal em
   produção — criar um usuário de CI com uma política mínima — está bloqueado.
   Por isso a autenticação usa as credenciais da **sessão**, que já vêm com o
   `aws_session_token`.
2. **As credenciais expiram a cada sessão.** Isso torna o script local o fluxo
   confiável, e o workflow do GitHub Actions a alternativa frágil: os secrets
   precisariam ser reconfigurados toda vez que o lab reinicia. Implementei o
   script como caminho principal justamente por isso.
3. **Região fixa em `us-east-1`.** Não é escolha de latência, é regra do lab.

> Aprendi essa restrição na prática: no TF de Big Data, uma SCP da organização
> negava `s3:GetBucketObjectLockConfiguration`, e o `aws_s3_bucket` do Terraform
> quebrava só por fazer essa leitura. A lição que carreguei para cá é que num
> ambiente com SCP o caminho mais curto raramente é o que funciona.

---

## 2. Estratégia de tagging

Três tags por build, cada uma com uma função distinta:

| Tag | Exemplo | Para que serve |
|---|---|---|
| `sha-XXXXXXX` | `sha-a3f91c2` | **rastreabilidade** — aponta para um commit exato |
| `latest` | `latest` | **conveniência** — o último build da branch principal |
| semver | `1.2.3`, `1.2`, `1` | **contrato de versão** para quem consome |

### Por que a tag de SHA é a que importa

`latest` é mutável: o que ela aponta hoje não é o que apontava ontem. Isso a
torna inútil para duas coisas críticas — **rollback** e **auditoria**. Se a
produção quebrar, "volte para a latest anterior" não é um comando executável,
porque a anterior não tem nome.

Com `sha-a3f91c2`, o rollback é literal:

```bash
docker pull <conta>.dkr.ecr.us-east-1.amazonaws.com/technova-api:sha-a3f91c2
```

E é auditável: do container em produção dá para chegar ao commit, ao PR, ao
autor e à revisão.

### Por que semver em cascata (`1.2.3`, `1.2`, `1`)

Permite que quem consome escolha **quanto risco aceita**: fixar em `1.2.3`
congela tudo; usar `1.2` recebe correções de bug; usar `1` recebe também
funcionalidades novas compatíveis. A tag só é publicada quando existe uma git
tag `v*.*.*`, então versionar é um ato deliberado, não um efeito colateral do
build.

---

## 3. O que o review verifica

São **12 padrões**, em três níveis de severidade:

| Severidade | Padrão | O que procura |
|---|---|---|
| 🔴 CRITICAL | `secret-hardcoded` | senha, token ou api_key atribuídos como string literal |
| 🔴 CRITICAL | `aws-access-key` | chaves `AKIA…`/`ASIA…` no código |
| 🔴 CRITICAL | `private-key` | bloco `BEGIN PRIVATE KEY` commitado |
| 🔴 CRITICAL | `eval` | `eval()` — executa texto arbitrário como código |
| 🔴 CRITICAL | `sql-injection` | SQL montado por concatenação ou template string |
| 🔴 CRITICAL | `command-injection` | `exec`/`spawn` com interpolação de variável |
| 🟡 WARNING | `console-log` | log de debug esquecido |
| 🟡 WARNING | `catch-vazio` | `catch {}` engolindo o erro |
| 🟡 WARNING | `bind-publico` | serviço escutando em `0.0.0.0` |
| 🟡 WARNING | `http-sem-tls` | URL externa em `http://` |
| 🔵 INFO | `todo` | `TODO`, `FIXME`, `HACK`, `XXX` |
| 🔵 INFO | `docker-latest` | imagem base fixada em `:latest` |

A régua da severidade é **a consequência de ignorar**: CRITICAL é o que vira
incidente de segurança; WARNING é o que vira dívida técnica; INFO é lembrete.

---

## 4. A lógica da análise — e por que ela não usa um modelo

O enunciado chama de "AI review", mas o laboratório orienta: *"Em produção, a
seção `analyzeWithAI` chamaria Bedrock/OpenAI. Para o lab, usamos análise
baseada em regras (pattern matching)."*

Mantive a análise **determinística**, e isso é uma escolha defensável, não uma
economia:

- **Um quality gate precisa ser reproduzível.** Se o mesmo diff pode passar numa
  execução e falhar na seguinte, o gate perde autoridade — e a primeira reação
  do time vira "roda de novo" em vez de "corrige".
- **Custo e latência previsíveis.** Não depende de API externa, chave, cota nem
  disponibilidade de terceiro dentro do caminho crítico do merge.
- **Sem vazamento de código.** O diff não sai da infraestrutura do CI.

O script analisa **apenas as linhas adicionadas** do diff. É uma decisão
importante: revisar o arquivo inteiro faria o PR ser reprovado por problemas que
já existiam antes dele, e o autor seria cobrado por dívida que não contraiu.

```
git diff BASE HEAD --unified=0
  → extrai só as linhas que começam com '+'
  → aplica os 12 padrões, linha a linha
  → agrupa por severidade
  → exit 1 se houver CRITICAL
```

O analisador também **se exclui da própria análise** — o arquivo contém, por
definição, todos os padrões que procura, e sem isso se auto-reprovaria.

---

## 5. A lógica do quality gate

```
achados CRITICAL > 0   →  exit 1  →  check vermelho  →  PR bloqueado
só WARNING / INFO      →  exit 0  →  check verde     →  PR liberado
```

Três decisões de desenho que valem explicar:

**O comentário é publicado antes do gate falhar.** O passo da análise roda com
`continue-on-error: true` e a falha é materializada num passo posterior. Sem
isso, o workflow morreria antes de comentar — e o autor veria um ✗ vermelho sem
nenhuma explicação do motivo.

**O comentário é atualizado, não duplicado.** O script marca o comentário com
`<!-- ai-review-bot -->`; a cada novo push o workflow procura essa marca e edita
o comentário existente. Um PR com 15 pushes teria 15 comentários idênticos, e aí
ninguém lê nenhum.

**Só CRITICAL bloqueia.** Se WARNING também travasse o merge, um `console.log`
esquecido teria o mesmo peso de uma credencial vazada. Gate que reclama de tudo
é gate que o time aprende a ignorar.

---

## 6. Quando confiar na automação, e quando exigir um humano

### Onde ela é melhor que uma pessoa

Em **consistência**. O revisor humano cansa, tem pressa na sexta à tarde, e
confia mais no código de quem ele conhece. O analisador verifica os 12 padrões
na milésima vez com o mesmo rigor da primeira. É particularmente bom em achados
objetivos e de alto custo: uma chave AWS commitada é sempre um problema,
independente do contexto.

### Onde ela não substitui ninguém

A análise estática enxerga **texto**, não **intenção**. Ela não responde:

- a regra de negócio implementada está correta?
- esta mudança quebra algum contrato de quem consome a API?
- a arquitetura escolhida vai se sustentar?
- falta um teste para o caso que ninguém pensou?
- este código, que passa em todos os padrões, está **certo**?

O modo saudável de usar é como **primeira camada**: ela elimina o óbvio para que
a atenção humana sobre no que exige julgamento. A pessoa que revisa não deveria
gastar seu tempo procurando `console.log`.

---

## 7. Limitações que identifiquei

**Falsos positivos que a régua produz**

- `const senha = 'exemplo'` numa fixture de teste é marcado como CRITICAL. É um
  teste, não um vazamento — mas o padrão não sabe distinguir.
- `http://` em comentário ou documentação dispara o alerta de TLS.
- `0.0.0.0` dentro de um container é frequentemente **correto**, porque é assim
  que o serviço fica acessível fora dele.

**Um falso negativo que encontrei testando — e corrigi**

A primeira versão da regra de credencial era:

```js
/(password|senha|secret|api[_-]?key|token)\s*[:=]\s*['"][^'"]{4,}['"]/gi
```

Ela pegava `const apiKey = "sk-..."` mas **deixava passar**
`const senhaDoBanco = 'Pr0ducao2026!'` — porque exigia a palavra-chave colada
no `=`, e ali vinha `DoBanco` no meio. Descobri isso rodando o PR de
demonstração: esperava 6 achados CRITICAL e vieram 5.

A correção foi aceitar afixos dos dois lados:

```js
/\w*(password|senha|secret|api[_-]?key|token)\w*\s*[:=]\s*['"][^'"]{4,}['"]/gi
```

Agora pega `senhaDoBanco`, `dbPassword`, `apiKeyProd` e `userToken`, e continua
ignorando `nomeDoUsuario`. O episódio é a própria tese deste documento em
miniatura: **a régua só enxerga o que alguém pensou em escrever nela**, e o
nome de variável que o desenvolvedor escolhe não tem obrigação de caber no
padrão.

**Outros falsos negativos — o que ainda passa batido**

- Credencial montada em partes: `const k = p1 + p2` não casa com nenhum padrão.
- SQL injection através de uma função intermediária, quando a concatenação
  acontece longe da chamada `query()`.
- Qualquer coisa em arquivo **removido ou renomeado** — só olho linhas
  adicionadas.
- Dependência vulnerável no `package.json`: isso exige `npm audit`, não regex.

**Limitações estruturais**

- **Sem contexto entre linhas.** A análise é linha a linha, então não detecta
  nada que dependa do fluxo do programa.
- **Sem entender o projeto.** Não sabe que este repositório é acadêmico e que
  `console.log` aqui é didático.
- **A régua envelhece.** Padrão novo de ataque não aparece sozinho; alguém
  precisa adicionar a regra.

**A limitação mais perigosa não é técnica**

É de comportamento: **o check verde pode virar permissão para não pensar**.
Quando o bot aprova, existe a tentação de assumir que o código está bom — quando
tudo o que ele disse foi "não encontrei os 12 problemas que sei procurar". A
automação reduz o custo da revisão; ela não transfere a responsabilidade.
