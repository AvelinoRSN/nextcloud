#!/bin/bash

# Configurações do PostgreSQL local
PGHOST_LOCAL="IP_LOCAL"
PGPORT_LOCAL="5432"
PGUSER_LOCAL="nextcloud"
PGDATABASE_LOCAL="nextcloud"

# Configurações do PostgreSQL no RDS da AWS
PGHOST_RDS="RDS_REMOTO"
PGPORT_RDS="5432"
PGUSER_RDS="postgres"
PGDATABASE_RDS="nextcloud"

# Caminhos
DUMP_FILE="nextcloud_dump.sql"
BACKUP_DIR="nextcloud_backup_$(date +%Y%m%d_%H%M%S)"
DATA_BACKUP="$BACKUP_DIR/data"

# Função para backup completo
backup_completo() {
    echo "=== INICIANDO BACKUP COMPLETO ==="
    
    # Criar diretório de backup
    mkdir -p "$DATA_BACKUP"
    
    # Backup do banco de dados
    echo "Fazendo dump do banco de dados local..."
    pg_dump -h $PGHOST_LOCAL -p $PGPORT_LOCAL -U $PGUSER_LOCAL -d $PGDATABASE_LOCAL -F c -b -v -f "$BACKUP_DIR/$DUMP_FILE"
    
    if [ $? -ne 0 ]; then
        echo "Erro ao fazer o dump do banco de dados local."
        exit 1
    fi
    
    # Backup dos arquivos preservando timestamps e permissões
    echo "Fazendo backup dos arquivos do Nextcloud..."
    docker exec nextcloud-nc-1 tar -czpf /tmp/nextcloud_data.tar.gz -C /var/www/html/data .
    docker cp nextcloud-nc-1:/tmp/nextcloud_data.tar.gz "$BACKUP_DIR/"
    docker exec nextcloud-nc-1 rm /tmp/nextcloud_data.tar.gz
    
    echo "Backup completo finalizado em: $BACKUP_DIR"
}

# Função para restore completo
restore_completo() {
    if [ -z "$1" ]; then
        echo "Uso: $0 restore <diretorio_backup>"
        exit 1
    fi
    
    RESTORE_DIR="$1"
    
    if [ ! -d "$RESTORE_DIR" ]; then
        echo "Diretório de backup não encontrado: $RESTORE_DIR"
        exit 1
    fi
    
    echo "=== INICIANDO RESTORE COMPLETO ==="
    
    # Restore do banco de dados
    echo "Dropando e recriando banco no RDS..."
    psql -h $PGHOST_RDS -U $PGUSER_RDS <<EOF
DROP DATABASE IF EXISTS $PGDATABASE_RDS;
CREATE DATABASE $PGDATABASE_RDS;
EOF
    
    echo "Restaurando dump no RDS..."
    pg_restore --no-owner --no-acl -h $PGHOST_RDS -p $PGPORT_RDS -U $PGUSER_RDS -d $PGDATABASE_RDS -v "$RESTORE_DIR/$DUMP_FILE"
    
    if [ $? -ne 0 ]; then
        echo "Erro ao restaurar o dump no RDS."
        exit 1
    fi
    
    # Restore dos arquivos preservando timestamps
    if [ -f "$RESTORE_DIR/nextcloud_data.tar.gz" ]; then
        echo "Restaurando arquivos do Nextcloud..."
        
        # Parar o container temporariamente
        docker stop nextcloud-nc-1
        
        # Limpar dados atuais
        docker run --rm -v nextcloud_nextcloud:/data alpine sh -c "rm -rf /data/*"
        
        # Restaurar arquivos preservando timestamps
        docker cp "$RESTORE_DIR/nextcloud_data.tar.gz" nextcloud-nc-1:/tmp/ 2>/dev/null || {
            # Se container não estiver rodando, usar volume mount
            docker run --rm -v nextcloud_nextcloud:/data -v "$PWD/$RESTORE_DIR":/backup alpine sh -c "cd /data && tar -xzpf /backup/nextcloud_data.tar.gz"
        }
        
        # Reiniciar container
        docker start nextcloud-nc-1
        
        # Aguardar container inicializar
        sleep 10
        
        # Executar rescan preservando timestamps
        echo "Executando rescan dos arquivos..."
        docker exec nextcloud-nc-1 php /var/www/html/occ files:scan --all
    fi
    
    echo "Restore completo finalizado!"
}

# Menu principal
case "$1" in
    "backup")
        backup_completo
        ;;
    "restore")
        restore_completo "$2"
        ;;
    *)
        echo "Uso: $0 {backup|restore <diretorio_backup>}"
        echo "Exemplos:"
        echo "  $0 backup"
        echo "  $0 restore nextcloud_backup_20241007_230940"
        exit 1
        ;;
esac
