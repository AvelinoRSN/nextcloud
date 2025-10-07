# Nextcloud com Auto-Instalação e RDS

Este projeto configura automaticamente o Nextcloud com banco PostgreSQL no RDS da AWS.

## Configuração Automática

### 1. Variáveis de Ambiente Necessárias

```yaml
environment:
  - POSTGRES_HOST=next-cloud-db.co308c48ebbz.us-east-1.rds.amazonaws.com
  - POSTGRES_PASSWORD=wYVzQH28ltyavZBudv9w
  - POSTGRES_DB=nextcloud
  - POSTGRES_USER=nextcloud_user
  - POSTGRES_USER_PASSWORD=nextcloud123
  - NEXTCLOUD_ADMIN_USER=admin
  - NEXTCLOUD_ADMIN_PASSWORD=admin123
  - NEXTCLOUD_TRUSTED_DOMAINS=localhost 54.156.72.54
  - AUTO_INSTALL=true
```

### 2. Instalação

```bash
# Construir e executar
docker compose up -d

# Aguardar instalação (pode levar alguns minutos)
docker logs nextcloud-nc-1 -f
```

### 3. Acesso

- **URL**: http://54.156.72.54
- **Usuário**: admin
- **Senha**: admin123

## O que é Configurado Automaticamente

✅ **Banco RDS**: Usuário e banco criados automaticamente  
✅ **Migrações**: Tabelas do Nextcloud criadas no RDS  
✅ **Trusted Domains**: IPs configurados para acesso externo  
✅ **Permissões**: Arquivos com permissões corretas  
✅ **Admin User**: Usuário administrador criado  

## Variáveis Opcionais

```yaml
# Para restaurar backup
- RESTORE_BACKUP_FILE=/opt/restores/backup.dump

# Para criar backup inicial
- CREATE_INITIAL_BACKUP=true
```

## Troubleshooting

Se houver problemas:

```bash
# Verificar logs
docker logs nextcloud-nc-1

# Reiniciar container
docker restart nextcloud-nc-1

# Verificar status da instalação
docker exec nextcloud-nc-1 php /var/www/html/occ status
```

## Estrutura dos Scripts

- `auto-install.sh`: Instalação automática do Nextcloud
- `init-migration.sh`: Configuração do banco RDS
- `docker-entrypoint.sh`: Orquestração de todos os scripts
- `compose.yml`: Configuração com todas as variáveis necessárias
