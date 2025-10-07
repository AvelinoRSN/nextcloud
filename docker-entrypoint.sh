#!/bin/bash

# Script de entrypoint unificado com migrações, restore e auto-instalação
set -e

echo "=== INICIANDO NEXTCLOUD COM MIGRAÇÕES E RESTORE ==="

# Verificar se deve fazer restore de backup preservando timestamps
if [ -n "$RESTORE_BACKUP_FILE" ] && [ -f "$RESTORE_BACKUP_FILE" ]; then
    echo "Restaurando backup do banco de dados..."
    /usr/local/bin/restore-database.sh -f "$RESTORE_BACKUP_FILE" --force
    echo "Restore concluído!"
fi

# Verificar se deve restaurar arquivos preservando timestamps
if [ -n "$RESTORE_DATA_FILE" ] && [ -f "$RESTORE_DATA_FILE" ]; then
    echo "Restaurando arquivos preservando timestamps..."
    cd /var/www/html/data
    tar -xzpf "$RESTORE_DATA_FILE"
    chown -R www-data:www-data /var/www/html/data
    echo "Arquivos restaurados com timestamps preservados!"
fi

# Executar migrações se as variáveis de banco estiverem definidas
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_DB" ]; then
    echo "Executando migrações de banco..."
    /usr/local/bin/init-migration.sh
else
    echo "Variáveis de banco não definidas - pulando migrações"
fi

# Verificar se deve fazer backup inicial
if [ "$CREATE_INITIAL_BACKUP" = "true" ]; then
    echo "Criando backup inicial..."
    /usr/local/bin/backup-database.sh -o "/opt/backups/initial_backup_$(date +%Y%m%d_%H%M%S).dump"
    echo "Backup inicial concluído!"
fi

# Iniciar Apache em background
echo "Iniciando Apache..."
/entrypoint.sh "$@" &
APACHE_PID=$!

# Executar auto-instalação se habilitada
if [ "$AUTO_INSTALL" = "true" ]; then
    echo "Executando auto-instalação em paralelo..."
    /usr/local/bin/auto-install.sh &
fi

# Aguardar o Apache
wait $APACHE_PID
