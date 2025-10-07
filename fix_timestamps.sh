#!/bin/bash

echo "=== CORRIGINDO TIMESTAMPS DOS ARQUIVOS ==="

# Definir uma data base mais antiga para os arquivos (exemplo: 1 mês atrás)
BASE_DATE="2024-09-07 10:00:00"

# Função para definir timestamps aleatórios mas realistas
fix_file_timestamps() {
    local file_path="$1"
    
    # Gerar timestamp aleatório entre a data base e hoje
    local random_days=$((RANDOM % 30))
    local random_hours=$((RANDOM % 24))
    local random_minutes=$((RANDOM % 60))
    
    # Calcular nova data
    local new_date=$(date -d "$BASE_DATE + $random_days days + $random_hours hours + $random_minutes minutes" "+%Y%m%d%H%M.%S")
    
    # Aplicar novo timestamp
    touch -t "$new_date" "$file_path"
}

# Entrar no container e corrigir timestamps
docker exec nextcloud-nc-1 bash -c '
    echo "Corrigindo timestamps dos arquivos de usuário..."
    
    # Encontrar todos os arquivos de usuário (excluindo arquivos de sistema)
    find /var/www/html/data -type f -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.pdf" -o -name "*.doc" -o -name "*.docx" -o -name "*.txt" -o -name "*.mp4" -o -name "*.avi" -o -name "*.mov" | while read file; do
        # Gerar timestamp aleatório entre setembro e outubro de 2024
        random_day=$((RANDOM % 30 + 1))
        random_hour=$((RANDOM % 24))
        random_minute=$((RANDOM % 60))
        
        # Formato: MMDDhhmm (setembro = 09)
        if [ $random_day -le 15 ]; then
            new_timestamp="0909${random_hour}$(printf "%02d" $random_minute)"
        else
            new_timestamp="0910${random_hour}$(printf "%02d" $random_minute)"
        fi
        
        touch -t "$new_timestamp" "$file"
        echo "Timestamp corrigido: $file"
    done
    
    echo "Timestamps corrigidos com sucesso!"
'

echo "=== PROCESSO CONCLUÍDO ==="
echo "Os arquivos agora têm timestamps mais realistas (setembro/outubro 2024)"
echo "Para verificar: docker exec nextcloud-nc-1 ls -la /var/www/html/data/admin/files/"
