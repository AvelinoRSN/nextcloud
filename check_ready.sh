#!/bin/bash

echo "🔍 Verificando se o Nextcloud está pronto..."

# Função para verificar se está pronto
check_ready() {
    # Verifica se o container está rodando
    if ! docker-compose ps | grep -q "Up"; then
        return 1
    fi
    
    # Verifica se responde HTTP 200
    if ! curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
        return 1
    fi
    
    # Verifica se a página de login carrega (não é erro 500)
    response=$(curl -s http://localhost)
    if echo "$response" | grep -q "Internal Server Error\|Fatal error\|Exception"; then
        return 1
    fi
    
    # Verifica se tem conteúdo HTML válido do Nextcloud
    if echo "$response" | grep -q "Nextcloud\|login"; then
        return 0
    fi
    
    return 1
}

# Loop de verificação
counter=0
while ! check_ready; do
    counter=$((counter + 1))
    echo "⏳ Aguardando... (${counter}0s)"
    
    if [ $counter -gt 30 ]; then
        echo "❌ Timeout: Aplicação não ficou pronta em 5 minutos"
        echo "📋 Verifique os logs: docker-compose logs nc"
        exit 1
    fi
    
    sleep 10
done

# Obter IP da máquina
IP="3.84.201.243"

echo ""
echo "✅ NEXTCLOUD ESTÁ PRONTO!"
echo "🌐 Acesse em: http://$IP"
echo "👤 Usuário: admin"
echo "🔑 Senha: admin123"
echo ""
echo "📊 Status do container:"
docker-compose ps
