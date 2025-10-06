#!/bin/bash

# Script de inicialização para migrações de banco de dados
set -e

echo "=== INICIANDO MIGRAÇÕES DE BANCO ==="

# Definir senha do PostgreSQL
export PGPASSWORD="$POSTGRES_PASSWORD"

# Aguardar o banco de dados estar disponível
echo "Aguardando banco de dados..."
until pg_isready -h "$POSTGRES_HOST" -p 5432 -U "$POSTGRES_USER"; do
    echo "Banco não disponível - aguardando..."
    sleep 2
done

echo "Banco disponível!"

# Verificar se o banco já existe
DB_EXISTS=$(psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DB'")

if [ "$DB_EXISTS" != "1" ]; then
    echo "Criando banco '$POSTGRES_DB'..."
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$POSTGRES_DB\";"
else
    echo "Banco '$POSTGRES_DB' já existe."
fi

# Executar migrações
if [ -d "/docker-entrypoint-initdb.d" ]; then
    echo "Executando migrações..."
    for migration in /docker-entrypoint-initdb.d/*.sql; do
        if [ -f "$migration" ]; then
            echo "Executando: $(basename "$migration")"
            psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$migration"
        fi
    done
fi

echo "=== MIGRAÇÕES CONCLUÍDAS ==="
