#!/bin/bash

# Script de instalação automática do Nextcloud com RDS
set -e

echo "=== INICIANDO INSTALAÇÃO AUTOMÁTICA DO NEXTCLOUD ==="

# Aguardar banco de dados
echo "Aguardando banco de dados..."
until pg_isready -h "$POSTGRES_HOST" -p 5432 -U postgres; do
    echo "Banco não disponível, aguardando..."
    sleep 5
done
echo "Banco disponível!"

# Criar usuário do banco se não existir
echo "Configurando usuário do banco..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U postgres -d postgres -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$POSTGRES_USER') THEN
        CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_USER_PASSWORD';
    END IF;
END
\$\$;
"

# Criar banco se não existir
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U postgres -d postgres -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$POSTGRES_DB') THEN
        EXECUTE 'CREATE DATABASE $POSTGRES_DB';
    END IF;
END
\$\$;
"

# Dar permissões
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U postgres -d postgres -c "
GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;
GRANT ALL ON SCHEMA public TO $POSTGRES_USER;
"

# Verificar se Nextcloud já está instalado
if [ ! -f /var/www/html/config/config.php ]; then
    echo "Aguardando Nextcloud estar pronto..."
    echo "Isso pode levar alguns minutos na primeira execução..."
    
    # Aguardar o arquivo occ estar disponível
    counter=0
    while [ ! -f /var/www/html/occ ]; do
        counter=$((counter + 1))
        echo "⏳ Aguardando inicialização do Nextcloud... (${counter}0s)"
        sleep 10
        
        if [ $counter -gt 30 ]; then
            echo "❌ Timeout aguardando Nextcloud. Verificando se Apache está rodando..."
            ps aux | grep apache2 || echo "Apache não está rodando"
            ls -la /var/www/html/ | head -10
            break
        fi
    done
    
    if [ -f /var/www/html/occ ]; then
        echo "✅ Nextcloud pronto! Iniciando instalação..."
    else
        echo "❌ Erro: Nextcloud não inicializou corretamente"
        exit 1
    fi
    
    echo "Instalando Nextcloud..."
    
    # Instalar via OCC
    php /var/www/html/occ maintenance:install \
        --database=pgsql \
        --database-name="$POSTGRES_DB" \
        --database-host="$POSTGRES_HOST" \
        --database-user="$POSTGRES_USER" \
        --database-pass="$POSTGRES_USER_PASSWORD" \
        --admin-user="$NEXTCLOUD_ADMIN_USER" \
        --admin-pass="$NEXTCLOUD_ADMIN_PASSWORD"
    
    echo "Nextcloud instalado com sucesso!"
    
    # Configurar trusted domains
    if [ ! -z "$NEXTCLOUD_TRUSTED_DOMAINS" ]; then
        echo "Configurando trusted domains..."
        IFS=' ' read -ra DOMAINS <<< "$NEXTCLOUD_TRUSTED_DOMAINS"
        for i in "${!DOMAINS[@]}"; do
            php /var/www/html/occ config:system:set trusted_domains $i --value="${DOMAINS[$i]}"
        done
    fi
    
    # Corrigir permissões
    chown -R www-data:www-data /var/www/html
    
    echo "Configuração concluída!"
else
    echo "Nextcloud já está instalado."
fi

echo "=== INSTALAÇÃO AUTOMÁTICA CONCLUÍDA ==="
