#!/bin/bash

# Script de restore de banco de dados para Nextcloud
# Este script restaura um backup do banco de dados PostgreSQL

set -e

# Configurações padrão
DEFAULT_HOST="${POSTGRES_HOST:-localhost}"
DEFAULT_PORT="${POSTGRES_PORT:-5432}"
DEFAULT_USER="${POSTGRES_USER:-nextcloud}"
DEFAULT_DB="${POSTGRES_DB:-nextcloud}"
DEFAULT_BACKUP_DIR="/opt/restores"

# Função para exibir uso
show_usage() {
    echo "Uso: restore-database.sh [opções]"
    echo ""
    echo "Opções:"
    echo "  -f, --file FILE        Arquivo de backup para restaurar"
    echo "  -h, --host HOST        Host do banco de dados (padrão: $DEFAULT_HOST)"
    echo "  -p, --port PORT        Porta do banco de dados (padrão: $DEFAULT_PORT)"
    echo "  -u, --user USER        Usuário do banco de dados (padrão: $DEFAULT_USER)"
    echo "  -d, --database DB      Nome do banco de dados (padrão: $DEFAULT_DB)"
    echo "  -b, --backup-dir DIR   Diretório de backups (padrão: $DEFAULT_BACKUP_DIR)"
    echo "  --force                Forçar restore sem confirmação"
    echo "  --dry-run              Simular restore sem executar"
    echo "  -v, --verbose          Modo verboso"
    echo "  --help                 Exibir esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  restore-database.sh -f backup.sql"
    echo "  restore-database.sh -f backup.dump --force"
    echo "  restore-database.sh -f backup.sql -h rds.amazonaws.com -u admin"
}

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para log verbose
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        log "$1"
    fi
}

# Função para verificar se o banco existe
check_database_exists() {
    local db_exists=$(psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DATABASE'" 2>/dev/null || echo "")
    if [ "$db_exists" = "1" ]; then
        return 0
    else
        return 1
    fi
}

# Função para criar banco de dados
create_database() {
    log "Criando banco de dados '$DATABASE'..."
    psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -c "CREATE DATABASE \"$DATABASE\";"
    if [ $? -eq 0 ]; then
        log "Banco de dados '$DATABASE' criado com sucesso!"
    else
        log "Erro ao criar banco de dados '$DATABASE'"
        exit 1
    fi
}

# Função para restaurar backup SQL
restore_sql_backup() {
    local backup_file="$1"
    log "Restaurando backup SQL: $backup_file"
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Seria executado: psql -h $HOST -p $PORT -U $USER -d $DATABASE -f $backup_file"
        return 0
    fi
    
    psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DATABASE" -f "$backup_file"
    if [ $? -eq 0 ]; then
        log "Backup SQL restaurado com sucesso!"
    else
        log "Erro ao restaurar backup SQL"
        exit 1
    fi
}

# Função para restaurar backup custom
restore_custom_backup() {
    local backup_file="$1"
    log "Restaurando backup custom: $backup_file"
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Seria executado: pg_restore --no-owner --no-acl -h $HOST -p $PORT -U $USER -d $DATABASE -v $backup_file"
        return 0
    fi
    
    pg_restore --no-owner --no-acl -h "$HOST" -p "$PORT" -U "$USER" -d "$DATABASE" -v "$backup_file"
    if [ $? -eq 0 ]; then
        log "Backup custom restaurado com sucesso!"
    else
        log "Erro ao restaurar backup custom"
        exit 1
    fi
}

# Função para restaurar backup
restore_backup() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        log "Erro: Arquivo de backup '$backup_file' não encontrado!"
        exit 1
    fi
    
    # Detectar tipo de backup pelo conteúdo ou extensão
    local file_ext="${backup_file##*.}"
    
    if [ "$file_ext" = "sql" ] || grep -q "^-- PostgreSQL database dump" "$backup_file" 2>/dev/null; then
        restore_sql_backup "$backup_file"
    elif [ "$file_ext" = "dump" ] || [ "$file_ext" = "backup" ] || file "$backup_file" | grep -q "PostgreSQL custom database dump"; then
        restore_custom_backup "$backup_file"
    else
        log "Tipo de backup não reconhecido. Tentando como SQL..."
        restore_sql_backup "$backup_file"
    fi
}

# Função para fazer backup antes do restore
backup_before_restore() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/backup_before_restore_$timestamp.sql"
    
    log "Fazendo backup do banco atual antes do restore..."
    log_verbose "Arquivo de backup: $backup_file"
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Seria executado: pg_dump -h $HOST -p $PORT -U $USER -d $DATABASE > $backup_file"
        return 0
    fi
    
    pg_dump -h "$HOST" -p "$PORT" -U "$USER" -d "$DATABASE" > "$backup_file"
    if [ $? -eq 0 ]; then
        log "Backup criado com sucesso: $backup_file"
    else
        log "Aviso: Não foi possível criar backup do banco atual"
    fi
}

# Função para verificar conectividade
check_connectivity() {
    log "Verificando conectividade com o banco de dados..."
    
    if ! pg_isready -h "$HOST" -p "$PORT" -U "$USER" >/dev/null 2>&1; then
        log "Erro: Não foi possível conectar ao banco de dados em $HOST:$PORT"
        log "Verifique se:"
        log "  - O banco de dados está rodando"
        log "  - As credenciais estão corretas"
        log "  - A rede permite conexões"
        exit 1
    fi
    
    log "Conectividade com banco de dados verificada com sucesso!"
}

# Função principal
main() {
    log "=== INICIANDO RESTORE DE BANCO DE DADOS ==="
    
    # Verificar se arquivo foi fornecido
    if [ -z "$BACKUP_FILE" ]; then
        log "Erro: Arquivo de backup não especificado!"
        show_usage
        exit 1
    fi
    
    # Verificar conectividade
    check_connectivity
    
    # Verificar se banco existe
    if check_database_exists; then
        log "Banco de dados '$DATABASE' já existe."
        
        if [ "$FORCE" != true ] && [ "$DRY_RUN" != true ]; then
            echo "ATENÇÃO: O banco de dados '$DATABASE' já existe!"
            echo "O restore irá sobrescrever os dados existentes."
            echo ""
            read -p "Deseja continuar? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "Restore cancelado pelo usuário."
                exit 0
            fi
        fi
        
        # Fazer backup antes do restore se solicitado
        if [ "$BACKUP_BEFORE_RESTORE" = true ]; then
            backup_before_restore
        fi
    else
        log "Banco de dados '$DATABASE' não existe. Será criado."
        create_database
    fi
    
    # Restaurar backup
    restore_backup "$BACKUP_FILE"
    
    log "=== RESTORE CONCLUÍDO COM SUCESSO ==="
}

# Inicializar variáveis com valores padrão
HOST="$DEFAULT_HOST"
PORT="$DEFAULT_PORT"
USER="$DEFAULT_USER"
DATABASE="$DEFAULT_DB"
BACKUP_DIR="$DEFAULT_BACKUP_DIR"
BACKUP_FILE=""
FORCE=false
DRY_RUN=false
VERBOSE=false
BACKUP_BEFORE_RESTORE=true

# Processar argumentos da linha de comando
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            BACKUP_FILE="$2"
            shift 2
            ;;
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -d|--database)
            DATABASE="$2"
            shift 2
            ;;
        -b|--backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-backup)
            BACKUP_BEFORE_RESTORE=false
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            log "Opção desconhecida: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Executar função principal
main
