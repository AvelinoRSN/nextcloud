#!/bin/bash

echo "=== CORRIGINDO TIMESTAMPS DOS ARQUIVOS ==="

# Entrar no container e corrigir timestamps com formato correto
docker exec nextcloud-nc-1 bash -c '
    echo "Corrigindo timestamps dos arquivos de usuário..."
    
    # Encontrar todos os arquivos de usuário
    find /var/www/html/data -type f -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.pdf" -o -name "*.doc" -o -name "*.docx" -o -name "*.txt" -o -name "*.mp4" -o -name "*.avi" -o -name "*.mov" | while read file; do
        # Gerar timestamp aleatório em setembro/outubro 2024
        random_day=$((RANDOM % 30 + 1))
        random_hour=$((RANDOM % 24))
        random_minute=$((RANDOM % 60))
        
        # Formato correto: YYYYMMDDHHMM (setembro = 09, outubro = 10)
        if [ $random_day -le 15 ]; then
            # Setembro 2024
            new_timestamp="202409$(printf "%02d%02d%02d" $random_day $random_hour $random_minute)"
        else
            # Outubro 2024  
            day_oct=$((random_day - 15))
            new_timestamp="202410$(printf "%02d%02d%02d" $day_oct $random_hour $random_minute)"
        fi
        
        touch -t "$new_timestamp" "$file"
        echo "Timestamp corrigido: $file -> $new_timestamp"
    done
    
    echo "Timestamps corrigidos com sucesso!"
'

echo "=== VERIFICANDO RESULTADOS ==="
docker exec nextcloud-nc-1 ls -la /var/www/html/data/admin/files/Photos/ | head -5
