#!/bin/bash

# Script para backup antes da migração do Docker para sistema local
# Execute este script ANTES de parar os containers

echo "=== BACKUP ANTES DA MIGRAÇÃO ==="
echo "Data: $(date)"
echo ""

# Criar diretório de backup
mkdir -p backup_migration_$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backup_migration_$(date +%Y%m%d_%H%M%S)"

echo "1. Fazendo backup dos dados do Nextcloud..."
docker cp $(docker-compose ps -q nc):/var/www/html ./$BACKUP_DIR/nextcloud_data

echo "2. Fazendo backup do banco de dados PostgreSQL..."
docker exec $(docker-compose ps -q db) pg_dump -U nextcloud nextcloud > ./$BACKUP_DIR/nextcloud_database.sql

echo "3. Salvando configuração atual do Docker Compose..."
cp compose.yml ./$BACKUP_DIR/

echo "4. Listando volumes Docker..."
docker volume ls | grep -E "(nc_data|db_data)" > ./$BACKUP_DIR/docker_volumes.txt

echo ""
echo "=== BACKUP CONCLUÍDO ==="
echo "Backup salvo em: ./$BACKUP_DIR/"
echo ""
echo "Próximos passos:"
echo "1. Instalar Apache, PHP e PostgreSQL no sistema"
echo "2. Extrair dados do backup"
echo "3. Configurar aplicação local"
