#!/bin/bash
# ============================================================================
# User Data - EC2 da aplicacao
# ============================================================================
# DESAFIO EXTRA 4: instala o cliente psql e testa a conexao automaticamente,
# gravando o resultado em log.
#
# Decisao de seguranca: o teste automatico verifica ALCANCE DE REDE ate a porta
# 5432, nao autenticacao. Autenticar exigiria a senha do banco aqui dentro - e
# o user data fica legivel no endpoint de metadados da instancia para qualquer
# processo que rode nela. Trocar um teste mais completo por vazamento de
# credencial nao compensa.
#
# O teste de autenticacao de verdade e feito por SSH, com a senha vindo do
# ambiente, e esta em /usr/local/bin/testar-rds.sh.
set -euxo pipefail

LOG=/var/log/technova-setup.log
exec > >(tee -a "$LOG") 2>&1

echo "=== inicio: $(date -Is) ==="

dnf update -y
dnf install -y postgresql15 nodejs npm nc

echo "=== versoes instaladas ==="
psql --version
node --version

# ---------------------------------------------------------------------------
# Teste automatico de alcance ao RDS
# ---------------------------------------------------------------------------
RDS_HOST="__RDS_ENDPOINT__"
RESULTADO=/var/log/technova-rds-check.log

{
  echo "=== teste de alcance ao RDS: $(date -Is) ==="
  echo "host: $RDS_HOST porta: 5432"

  # /dev/tcp e um recurso do proprio bash: abre um socket sem depender de
  # ferramenta externa estar instalada.
  if timeout 10 bash -c "cat < /dev/null > /dev/tcp/${RDS_HOST}/5432" 2>/dev/null; then
    echo "RESULTADO: porta 5432 ALCANCAVEL"
    echo "  -> rota, DNS e security group estao corretos"
  else
    echo "RESULTADO: porta 5432 INALCANCAVEL"
    echo "  -> verificar security group do RDS e o db_subnet_group"
  fi
} | tee -a "$RESULTADO"

# ---------------------------------------------------------------------------
# Script de teste com autenticacao (rodado manualmente por SSH)
# ---------------------------------------------------------------------------
cat > /usr/local/bin/testar-rds.sh <<'SCRIPT'
#!/bin/bash
# Testa a conexao autenticada ao RDS e cria dados de evidencia.
# A senha vem do ambiente, nunca de arquivo em disco:
#   PGPASSWORD='...' /usr/local/bin/testar-rds.sh
set -euo pipefail

: "${PGPASSWORD:?defina PGPASSWORD antes de rodar}"
HOST="__RDS_ENDPOINT__"
USER="__DB_USER__"
DB="__DB_NAME__"

echo "=== 1. versao do servidor ==="
psql -h "$HOST" -U "$USER" -d "$DB" -c "SELECT version();"

echo "=== 2. criando tabela e dados ==="
psql -h "$HOST" -U "$USER" -d "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS orders (
    id          SERIAL PRIMARY KEY,
    cliente     TEXT        NOT NULL,
    produto     TEXT        NOT NULL,
    valor       NUMERIC(10,2) NOT NULL,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO orders (cliente, produto, valor) VALUES
    ('Ana Souza',      'Notebook TechNova 14',  4299.00),
    ('Bruno Lima',     'Monitor 27 polegadas',  1899.90),
    ('Carla Mendes',   'Teclado mecanico',       459.00);
SQL

echo "=== 3. consultando os dados persistidos ==="
psql -h "$HOST" -U "$USER" -d "$DB" -c "SELECT * FROM orders ORDER BY id;"

echo "=== 4. confirmando que os dados estao no RDS, nao em memoria ==="
psql -h "$HOST" -U "$USER" -d "$DB" -c "SELECT count(*) AS total_pedidos FROM orders;"
SCRIPT
chmod +x /usr/local/bin/testar-rds.sh

echo "=== fim: $(date -Is) ==="
