@echo off
echo Construindo Nextcloud com migrações de banco...
echo.

REM Verificar se a pasta migrations existe
if not exist "migrations" (
    echo Criando pasta migrations...
    mkdir migrations
)

REM Construir a imagem
docker build -t nextcloud-custom:latest .

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Imagem construída com sucesso!
    echo.
    echo Para executar com migrações:
    echo docker-compose up -d
    echo.
    echo Para adicionar novas migrações:
    echo 1. Coloque arquivos .sql na pasta migrations/
    echo 2. Use numeração sequencial: 01_nome.sql, 02_nome.sql, etc.
    echo 3. Reconstrua: docker build -t nextcloud-custom:latest .
    echo.
    echo Para ver as imagens disponíveis:
    echo docker images ^| grep nextcloud
) else (
    echo.
    echo ❌ Erro ao construir a imagem!
)

pause
