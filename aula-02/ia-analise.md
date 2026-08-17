# Análise do Uso de IA — Aula 02 TF

## Prompt Utilizado

> "Crie um docker-compose.yml para uma aplicação Node.js 20 com Express que usa PostgreSQL 15 como banco de dados e Redis 7 como cache. A API roda na porta 3000. O PostgreSQL precisa de volume nomeado para persistência. Todos os serviços devem estar na mesma rede bridge customizada. Use variáveis de ambiente com interpolação de arquivo .env. Adicione healthchecks, depends_on com condition, e restart policy unless-stopped."

## Output Original do Kiro

```yaml
version: '3.9'

services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=postgres
      - DB_PASSWORD=postgres
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped
    networks:
      - app-net

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=technova
    volumes:
      - db-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - app-net

  redis:
    image: redis:7
    ports:
      - "6379:6379"
    restart: unless-stopped
    networks:
      - app-net

volumes:
  db-data:

networks:
  app-net:
    driver: bridge
```

## Alterações que Fiz Manualmente

| O que mudei | Por quê |
|-------------|---------|
| Removi `version: '3.9'` do topo | Docker Compose v2+ ignora e alerta como obsoleto. Deixar limpo. |
| Troquei imagens `postgres:15` / `redis:7` por `postgres:15-alpine` / `redis:7-alpine` | Alpine é bem mais leve (~50MB vs ~380MB), suficiente pra dev. Foi o padrão que aprendi na aula 01. |
| Substituí todas as variáveis hardcoded (`DB_USER=postgres`, senhas) por interpolação `${VAR}` do `.env` | O prompt pediu explicitamente `.env` mas o Kiro esqueceu — deixou tudo hardcoded. Senhas versionadas no repo é um risco de segurança clássico. |
| Criei `.env` (não versionado) + `.env.example` (versionado) | Padrão da indústria: `.env` real fora do git, `.env.example` como template pro time saber quais variáveis existem. |
| Adicionei `healthcheck` no Redis (`redis-cli ping`) | Kiro só pôs healthcheck no Postgres. Como o `depends_on` da API depende do Redis também, faz sentido ter healthcheck nele pra garantir ordem de subida correta. |
| Mudei `condition: service_started` do Redis pra `condition: service_healthy` | Agora que o Redis tem healthcheck, dá pra esperar ele estar realmente pronto (não só o processo iniciado). |
| Mudei portas do host: PostgreSQL `5433:5432` e Redis `6380:6379` | Meu PC já tem Postgres (5432) e Redis (6379) rodando pra outros projetos. Sem essa mudança, `docker compose up` falharia por porta ocupada. |
| Adicionei `container_name` explícito em cada serviço | Facilita `docker exec technova-postgres ...` sem depender do nome auto-gerado pelo Compose. |
| Adicionei `start_period: 10s` no healthcheck do Postgres | Sem isso, o Compose considerava unhealthy nos primeiros segundos e a API tentava subir antes do banco estar realmente respondendo. |
| Nomeei o volume (`name: technova-postgres-data`) e a rede (`name: technova-net`) | Sem `name:`, o Compose prefixa com o nome do diretório. Se eu renomear a pasta perco os dados. Nome fixo protege. |
| Adicionei comentários em cada seção do YAML | O Kiro não comentou nada. Ajuda quem for ler depois (eu mesmo em 2 semanas). |
| Passei mais variáveis pra API (`DB_NAME`, `NODE_ENV`, etc) | O `app.js` do TF usa `DB_NAME` na URL do banco, mas o Kiro não passou. Se eu não notasse, a API subiria mas mostraria `undefined` no endpoint. |

## O que o Kiro Acertou

- Estrutura geral do arquivo correta: 3 serviços, volume, rede — cumpriu o pedido do prompt no macro.
- `depends_on` com `condition: service_healthy` no Postgres (bem feito).
- Healthcheck do Postgres com `pg_isready` é o padrão que a documentação oficial recomenda.
- Colocou volume nomeado (não bind mount aleatório) pra dados do Postgres.
- Rede bridge customizada em vez de usar a `default`.
- Usou `restart: unless-stopped` como pedi (é o mais seguro pra dev — não reinicia se eu parar manualmente).

## O que o Kiro Errou ou Omitiu

- **Ignorou o `.env`** que o prompt pediu explicitamente — deixou tudo hardcoded, incluindo senha.
- **Nenhum healthcheck no Redis** — inconsistente já que o Postgres tem.
- **Não avisou sobre porta ocupada** — em ambientes reais é comum ter serviço local já usando 5432/6379.
- **Não nomeou volumes/redes** — vulnerável ao nome da pasta.
- **Zero comentários** — o arquivo é entregue "cru".
- Colocou `version: '3.9'` que a v2+ do Compose considera obsoleto.
- Usou imagens não-Alpine sem justificar (mais pesadas).
- Só passou 4 variáveis pra API, faltou `DB_NAME` que o app precisa.

## Minha Avaliação

- **Tempo economizado usando IA:** ~15 min (não precisei lembrar toda a sintaxe de healthcheck, depends_on com condition e volume nomeado)
- **Tempo gasto validando/corrigindo:** ~25 min (mais tempo do que economizei, mas boa parte foi aprendizado — próxima vez será mais rápido)
- **Nota para o output da IA (1-10):** **6** — funcional mas com problemas críticos de segurança (senhas hardcoded) e boas práticas ignoradas mesmo depois de eu ter pedido no prompt.
- **Usaria novamente para este tipo de tarefa?** **Sim**, mas tratando o output como *rascunho*, nunca como versão pronta. IA é ótima pra sair de zero, mas revisão humana é obrigatória — principalmente em coisas que envolvem segurança, portas, credenciais e produção.
