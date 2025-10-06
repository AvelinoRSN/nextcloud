#!/bin/bash

# Script de backup de banco de dados para Nextcloud
# Este script faz backup do banco de dados PostgreSQL

set -e

# Configurações padrão
DEFAULT_HOST="${POSTGRES_HOST:-localhost}"
DEFAULT_PORT="${POSTGRES_PORT:-5432}"
DEFAULT_USER="${POSTGRES_USER:-nextcloud}"
DEFAULT_DB="${POSTGRES_DB:-nextcloud}"
DEFAULT_BACKUP_DIR="/opt/backups"

# Função para exibir uso
show_usage() {
    echo "Uso: backup-database.sh [opções]"
    echo ""
    echo "Opções:"
    echo "  -o, --output FILE      Arquivo de backup de saída"
    echo "  -h, --host HOST        Host do banco de dados (padrão: $DEFAULT_HOST)"
    echo "  -p, --port PORT        Porta do banco de dados (padrão: $DEFAULT_PORT)"
    echo "  -u, --user USER        Usuário do banco de dados (padrão: $DEFAULT_USER)"
    echo "  -d, --database DB      Nome do banco de dados (padrão: $DEFAULT_DB)"
    echo "  -b, --backup-dir DIR   Diretório de backups (padrão: $DEFAULT_BACKUP_DIR)"
    echo "  -f, --format FORMAT    Formato do backup: sql, custom, directory (padrão: custom)"
    echo "  --compress             Comprimir backup (apenas para custom)"
    echo "  --data-only            Backup apenas dos dados (sem schema)"
    echo "  --schema-only          Backup apenas do schema (sem dados)"
    echo "  --dry-run              Simular backup sem executar"
    echo "  -v, --verbose          Modo verboso"
    echo "  --help                 Exibir esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  backup-database.sh"
    echo "  backup-database.sh -o my_backup.sql -f sql"
    echo "  backup-database.sh -f custom --compress"
    echo "  backup-database.sh -h rds.amazonaws.com -u admin"
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

# Função para gerar nome do arquivo de backup
generate_backup_filename() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local format="$1"
    
    case "$format" in
        "sql")
            echo "${DATABASE}_backup_${timestamp}.sql"
            ;;
        "custom")
            echo "${DATABASE}_backup_${timestamp}.dump"
            ;;
        "directory")
            echo "${DATABASE}_backup_${timestamp}"
            ;;
        *)
            echo "${DATABASE}_backup_${timestamp}.dump"
            ;;
    esac
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

# Função para verificar se banco existe
check_database_exists() {
    local db_exists=$(psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DATABASE'" 2>/dev/null || echo "")
    if [ "$db_exists" = "1" ]; then
        return 0
    else
        return 1
    fi
}

# Função para fazer backup SQL
backup_sql() {
    local output_file="$1"
    log "Fazendo backup SQL: $output_file"
    
    local pg_dump_cmd="pg_dump -h $HOST -p $PORT -U $USER -d $DATABASE"
    
    # Adicionar opções específicas
    if [ "$DATA_ONLY" = true ]; then
        pg_dump_cmd="$pg_dump_cmd --data-only"
    elif [ "$SCHEMA_ONLY" = true ]; then
        pg_dump_cmd="$pg_dump_cmd --schema-only"
    fi
    
    # Adicionar verbose se solicitado
    if [ "$VERBOSE" = true ]; then
        pg_dump_cmd="$pg_dump_cmd -v"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Seria executado: $pg_dump_cmd > $output_file"
        return 0
    fi
    
    eval "$pg_dump_cmd" > "$output_file"
    if [ $? -eq 0 ]; then
        log "Backup SQL criado com sucesso: $output_file"
    else
        log "Erro ao criar backup SQL"
        exit 1
    fi
}

# Função para fazer backup custom
backup_custom() {
    local output_file="$1"
    log "Fazendo backup custom: $output_file"
    
    local pg_dump_cmd="pg_dump -h $HOST -p $PORT -U $USER -d $DATABASE -Fc"
    
    # Adicionar opções específicas
    if [ "$DATA_ONLY" = true ]; then
        pg_dump_cmd="$pg_dump_cmd --data-only"
    elif [ "$SCHEMA_ONLY" = true ]; then
        pg_dump_cmd="$pg_dump_cmd --schema-only"
    fi
    
    # Adicionar compressão se solicitado
    if [ "$COMPRESS" = true ]; then
        pg_dump_cmd="$pg_dump_cmd -Z 9"
    fi
    
    # Adicionar verbose se solicitado
    if [ "$VERBOSE" = true ]; then
        pg_dump_cmd="$pg_dump_cmd -v"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Seria executado: $pg_dump_cmd -f $output_file"
        return 0
    fi
    
    eval "$pg_dump_cmd" -f "$output_file"
    if [ $? -eq 0 ]; then
        log "Backup custom criado com sucesso: $output_file"
    else
        log "Erro ao criar backup custom"
        exit 1
    fi
}

# Função para fazer backup directory
backup_directory() {
    local output_dir="$1"
    log "Fazendo backup directory: $output_dir"
    
    local pg_dump_cmd="pg_dump -h $HOST -p $PORT -U $USER -d $DATABASE -Fd"
    
    # Adicionar opções específicas
    if [ "$DATA_ONLY" = true ]; then
        pg_dump_cmd="$pg_dump_cmd --data-only"
    elif [ "$SCHEMA_ONLY" = true ]; then
        pg_dump_cmd="$pg_dump_cmd --schema-only"
    fi
    
    # Adicionar compressão se solicitado
    if [ "$COMPRESS" = true ]; then
        pg_dump_cmd="$pg_dump_cmd -Z 9"
    fi
    
    # Adicionar verbose se solicitado
    if [ "$VERBOSE" = true ]; then
        pg_dump_cmd="$pg_dump_cmd -v"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Seria executado: $pg_dump_cmd -f $output_dir"
        return 0
    fi
    
    eval "$pg_dump_cmd" -f "$output_dir"
    if [ $? -eq 0 ]; then
        log "Backup directory criado com sucesso: $output_dir"
    else
        log "Erro ao criar backup directory"
        exit 1
    fi
}

# Função para mostrar informações do backup
show_backup_info() {
    local backup_file="$1"
    
    if [ -f "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        log "Tamanho do backup: $size"
        
        if [ "$VERBOSE" = true ]; then
            log "Permissões: $(ls -la "$backup_file")"
        fi
    elif [ -d "$backup_file" ]; then
        local size=$(du -sh "$backup_file" | cut -f1)
        log "Tamanho do backup directory: $size"
        
        if [ "$VERBOSE" = true ]; then
            log "Conteúdo do directory:"
            ls -la "$backup_file"
        fi
    fi
}

# Função para limpar backups antigos
cleanup_old_backups() {
    if [ "$CLEANUP_DAYS" -gt 0 ]; then
        log "Removendo backups antigos (mais de $CLEANUP_DAYS dias)..."
        
        local find_cmd="find $BACKUP_DIR -name '${DATABASE}_backup_*' -type f -mtime +$CLEANUP_DAYS"
        local find_cmd_dir="find $BACKUP_DIR -name '${DATABASE}_backup_*' -type d -mtime +$CLEANUP_DAYS"
        
        if [ "$DRY_RUN" = true ]; then
            log "DRY RUN: Seria executado: $find_cmd -delete"
            log "DRY RUN: Seria executado: $find_cmd_dir -exec rm -rf {} +"
            return 0
        fi
        
        eval "$find_cmd" -delete 2>/dev/null || true
        eval "$find_cmd_dir" -exec rm -rf {} + 2>/dev/null || true
        
        log "Limpeza de backups antigos concluída!"
    fi
}

# Função principal
main() {
    log "=== INICIANDO BACKUP DE BANCO DE DADOS ==="
    
    # Verificar conectividade
    check_connectivity
    
    # Verificar se banco existe
    if ! check_database_exists; then
        log "Erro: Banco de dados '$DATABASE' não existe!"
        exit 1
    fi
    
    # Gerar nome do arquivo se não fornecido
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$BACKUP_DIR/$(generate_backup_filename "$FORMAT")"
    fi
    
    # Criar diretório de backup se não existir
    if [ "$DRY_RUN" != true ]; then
        mkdir -p "$(dirname "$OUTPUT_FILE")"
    fi
    
    # Fazer backup baseado no formato
    case "$FORMAT" in
        "sql")
            backup_sql "$OUTPUT_FILE"
            ;;
        "custom")
            backup_custom "$OUTPUT_FILE"
            ;;
        "directory")
            backup_directory "$OUTPUT_FILE"
            ;;
        *)
            log "Formato não reconhecido: $FORMAT"
            exit 1
            ;;
    esac
    
    # Mostrar informações do backup
    show_backup_info "$OUTPUT_FILE"
    
    # Limpar backups antigos
    cleanup_old_backups
    
    log "=== BACKUP CONCLUÍDO COM SUCESSO ==="
    log "Arquivo: $OUTPUT_FILE"
}

# Inicializar variáveis com valores padrão
HOST="$DEFAULT_HOST"
PORT="$DEFAULT_PORT"
USER="$DEFAULT_USER"
DATABASE="$DEFAULT_DB"
BACKUP_DIR="$DEFAULT_BACKUP_DIR"
OUTPUT_FILE=""
FORMAT="custom"
COMPRESS=false
DATA_ONLY=false
SCHEMA_ONLY=false
DRY_RUN=false
VERBOSE=false
CLEANUP_DAYS=0

# Processar argumentos da linha de comando
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
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
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        --compress)
            COMPRESS=true
            shift
            ;;
        --data-only)
            DATA_ONLY=true
            shift
            ;;
        --schema-only)
            SCHEMA_ONLY=true
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
        --cleanup-days)
            CLEANUP_DAYS="$2"
            shift 2
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
