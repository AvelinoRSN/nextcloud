#!/bin/bash

# Script de entrypoint unificado com migrações e restore
set -e

echo "=== INICIANDO NEXTCLOUD COM MIGRAÇÕES E RESTORE ==="

# Verificar se deve fazer restore de backup
if [ -n "$RESTORE_BACKUP_FILE" ] && [ -f "$RESTORE_BACKUP_FILE" ]; then
    echo "Restaurando backup do banco de dados..."
    /usr/local/bin/restore-database.sh -f "$RESTORE_BACKUP_FILE" --force
    echo "Restore concluído!"
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

# Executar o entrypoint original do Nextcloud
echo "Iniciando Nextcloud..."
exec /entrypoint.sh "$@"
