# 📚 DOCUMENTAÇÃO DE INSTALAÇÃO E MIGRAÇÃO - NEXTCLOUD

## 📋 ÍNDICE

1. [Visão Geral do Projeto](#visão-geral-do-projeto)
2. [Pré-requisitos](#pré-requisitos)
3. [Instalação Local](#instalação-local)
4. [Configuração do Ambiente](#configuração-do-ambiente)
5. [Migração para AWS](#migração-para-aws)
6. [Deploy em EC2](#deploy-em-ec2)
7. [Auto Scaling](#auto-scaling)
8. [Configuração de Produção](#configuração-de-produção)
9. [Backup e Restore](#backup-e-restore)
10. [Monitoramento](#monitoramento)
11. [Troubleshooting](#troubleshooting)
12. [Manutenção](#manutenção)

---

## 🎯 VISÃO GERAL DO PROJETO

### **Descrição**

Sistema Nextcloud containerizado com migrações automáticas de banco de dados PostgreSQL, backup/restore automatizado e deploy otimizado para AWS EC2.

### **Arquitetura**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   EC2 Instance  │    │   RDS PostgreSQL│
│   (ALB/NLB)     │───▶│   Docker Host   │───▶│   (Managed DB)  │
│                 │    │   + Nextcloud   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                       ┌─────────────────┐
                       │   EBS/EFS       │
                       │   (File Storage)│
                       └─────────────────┘
```

### **Componentes Principais**

- **Nextcloud**: Aplicação principal
- **PostgreSQL**: Banco de dados
- **Redis**: Cache de sessões
- **Nginx**: Proxy reverso e SSL
- **Docker Compose**: Orquestração de containers

---

## ✅ PRÉ-REQUISITOS

### **Sistema Local (Desenvolvimento)**

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git
- 4GB RAM mínimo
- 20GB espaço em disco

### **AWS (Produção)**

- Conta AWS ativa
- AWS CLI configurado
- ECR Repository criado
- RDS PostgreSQL configurado
- EC2 Instance (t3.medium+)
- Security Groups configurados

### **Conhecimentos Necessários**

- Docker básico
- AWS básico
- PostgreSQL básico
- Linux básico

---

## 🏠 INSTALAÇÃO LOCAL

### **1. Clone do Repositório**

```bash
git clone <seu-repositorio>
cd nextcloud
```

### **2. Configuração do Ambiente Local**

```bash
# Criar arquivo de ambiente
cp .env.example .env

# Editar configurações
nano .env
```

**Conteúdo do .env:**

```env
# Configurações do Banco
POSTGRES_HOST=db
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=nextcloud123
POSTGRES_DB=nextcloud

# Configurações do Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=admin123
TRUSTED_DOMAINS=localhost

# Configurações Redis
REDIS_PASSWORD=redis123

# Configurações AWS (para produção)
AWS_REGION=us-east-1
ECR_REGISTRY=380278406175.dkr.ecr.us-east-1.amazonaws.com
```

### **3. Build e Execução Local**

#### **Build da Imagem Personalizada**

```bash
# Build da imagem usando o Dockerfile personalizado
docker build -t nextcloud-custom:latest .

# Verificar se a imagem foi criada
docker images | grep nextcloud-custom

# Build com cache (para builds subsequentes)
docker build --cache-from nextcloud-custom:latest -t nextcloud-custom:latest .
```

#### **Execução com Docker Compose**

```bash
# Executar com Docker Compose
docker-compose up -d

# Verificar status dos containers
docker-compose ps

# Verificar logs em tempo real
docker-compose logs -f

# Verificar logs específicos do Nextcloud
docker-compose logs -f nextcloud
```

#### **Verificação da Instalação**

```bash
# Verificar se os scripts estão disponíveis no container
docker-compose exec nextcloud ls -la /usr/local/bin/ | grep -E "(init-migration|restore-database|backup-database)"

# Verificar diretórios de backup/restore
docker-compose exec nextcloud ls -la /opt/backups /opt/restores

# Testar conectividade com banco
docker-compose exec nextcloud pg_isready -h db -p 5432 -U nextcloud
```

### **4. Acesso Local**

- **URL**: http://localhost
- **Admin**: admin / admin123
- **Status**: http://localhost/status.php

---

## ⚙️ CONFIGURAÇÃO DO AMBIENTE

### **1. Estrutura de Arquivos**

```
nextcloud/
├── Dockerfile                 # Imagem personalizada
├── docker-compose.yml         # Orquestração local
├── docker-compose.prod.yml    # Orquestração produção
├── .env                       # Variáveis de ambiente
├── .env.production           # Variáveis de produção
├── docker-entrypoint.sh      # Script de inicialização
├── init-migration.sh         # Executor de migrações
├── backup_migration.sh       # Backup antes migração
├── backup_restore_exemplo.sh # Exemplo de restore
├── build_image.bat          # Script Windows build
├── buildspec.yml            # AWS CodeBuild
├── migrations/              # Scripts SQL
│   ├── 01_init_database.sql
│   └── 02_custom_tables.sql
├── scripts/                 # Scripts utilitários
│   ├── start-nextcloud.sh
│   ├── backup.sh
│   └── health-check.sh
└── nextcloud/              # Código fonte
```

### **2. Dockerfile Personalizado**

#### **Estrutura e Funcionalidades**

O Dockerfile personalizado foi desenvolvido especificamente para este projeto Nextcloud, incorporando funcionalidades avançadas de migração, backup e restore:

```dockerfile
# Dockerfile unificado para Nextcloud com migrações e restore
FROM nextcloud:apache

# Instalar dependências necessárias
RUN apt-get update && apt-get install -y \
    postgresql-client \
    curl \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copiar arquivos da aplicação Nextcloud
COPY nextcloud/ /var/www/html/

# Copiar e configurar migrações
COPY migrations/ /docker-entrypoint-initdb.d/

# Copiar scripts de migração e restore
COPY init-migration.sh /usr/local/bin/
COPY restore-database.sh /usr/local/bin/
COPY backup-database.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-migration.sh \
    && chmod +x /usr/local/bin/restore-database.sh \
    && chmod +x /usr/local/bin/backup-database.sh

# Criar diretórios para backups e restores
RUN mkdir -p /opt/backups \
    && mkdir -p /opt/restores \
    && chmod 755 /opt/backups \
    && chmod 755 /opt/restores

# Definir permissões corretas
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Expor porta 80
EXPOSE 80

# Script de inicialização com migrações e restore
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
```

#### **Características Principais**

- **Base**: Utiliza a imagem oficial `nextcloud:apache` como base
- **Dependências**: Instala PostgreSQL client, curl, wget e unzip
- **Migrações Automáticas**: Copia scripts SQL para `/docker-entrypoint-initdb.d/`
- **Scripts Integrados**: Inclui scripts de migração, backup e restore
- **Diretórios de Trabalho**: Cria `/opt/backups` e `/opt/restores` para gerenciamento
- **Permissões**: Configura ownership e permissões corretas para www-data
- **Entrypoint Customizado**: Utiliza script personalizado para inicialização

#### **Scripts de Migração**

```sql
-- migrations/01_init_database.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- migrations/02_custom_tables.sql
CREATE TABLE IF NOT EXISTS oc_custom_settings (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    setting_key VARCHAR(255) NOT NULL,
    setting_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, setting_key)
);

CREATE INDEX idx_custom_settings_user ON oc_custom_settings(user_id);
```

#### **Funcionalidades de Backup e Restore**

O Dockerfile integra scripts avançados de backup e restore:

- **`restore-database.sh`**: Script completo de restore com múltiplas opções
- **`backup-database.sh`**: Script de backup com diferentes formatos
- **Diretórios**: `/opt/backups` e `/opt/restores` para gerenciamento de arquivos
- **Integração**: Scripts são executados automaticamente durante inicialização

#### **Otimizações do Dockerfile**

```dockerfile
# Otimizações para produção
# 1. Usar multi-stage build para reduzir tamanho
# 2. Cache de layers para builds mais rápidos
# 3. Limpeza de cache APT
# 4. Permissões mínimas necessárias

# Exemplo de build otimizado
docker build \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --cache-from nextcloud-custom:latest \
  -t nextcloud-custom:latest \
  .
```

#### **Variáveis de Ambiente Suportadas**

O Dockerfile personalizado suporta as seguintes variáveis de ambiente:

```bash
# Configurações de Banco de Dados
POSTGRES_HOST=db
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=nextcloud123
POSTGRES_DB=nextcloud

# Configurações do Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=admin123
TRUSTED_DOMAINS=localhost

# Configurações de Restore
RESTORE_BACKUP_FILE=/opt/restores/backup.dump
CREATE_INITIAL_BACKUP=true

# Configurações de Backup
BACKUP_FORMAT=dump
BACKUP_COMPRESSION=true
```

### **3. Scripts de Inicialização**

#### **docker-entrypoint.sh**

```bash
#!/bin/bash
set -e

echo "=== INICIANDO NEXTCLOUD COM MIGRAÇÕES ==="

# Executar migrações se variáveis definidas
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_DB" ]; then
    echo "Executando migrações de banco..."
    /usr/local/bin/init-migration.sh
else
    echo "Variáveis de banco não definidas - pulando migrações"
fi

# Iniciar Nextcloud
echo "Iniciando Nextcloud..."
exec /entrypoint.sh "$@"
```

#### **init-migration.sh**

```bash
#!/bin/bash
set -e

echo "=== INICIANDO MIGRAÇÕES DE BANCO ==="

# Aguardar banco disponível
until pg_isready -h "$POSTGRES_HOST" -p 5432 -U "$POSTGRES_USER"; do
    echo "Banco não disponível - aguardando..."
    sleep 2
done

# Criar banco se não existir
DB_EXISTS=$(psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DB'")

if [ "$DB_EXISTS" != "1" ]; then
    echo "Criando banco '$POSTGRES_DB'..."
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$POSTGRES_DB\";"
fi

# Executar migrações
for migration in /docker-entrypoint-initdb.d/*.sql; do
    if [ -f "$migration" ]; then
        echo "Executando: $(basename "$migration")"
        psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$migration"
    fi
done

echo "=== MIGRAÇÕES CONCLUÍDAS ==="
```

---

## ☁️ MIGRAÇÃO PARA AWS

### **1. Preparação da AWS**

#### **Criar ECR Repository**

```bash
# Criar repository
aws ecr create-repository \
  --repository-name nextcloud \
  --region us-east-1

# Obter URI
aws ecr describe-repositories \
  --repository-names nextcloud \
  --region us-east-1 \
  --query 'repositories[0].repositoryUri' \
  --output text
```

#### **Criar RDS PostgreSQL**

```bash
# Criar subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name nextcloud-subnet-group \
  --db-subnet-group-description "Subnet group para Nextcloud" \
  --subnet-ids subnet-12345 subnet-67890

# Criar RDS instance
aws rds create-db-instance \
  --db-instance-identifier nextcloud-db \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 14.7 \
  --master-username nextcloud \
  --master-user-password SuaSenhaSegura123! \
  --allocated-storage 20 \
  --db-subnet-group-name nextcloud-subnet-group \
  --vpc-security-group-ids sg-12345 \
  --backup-retention-period 7 \
  --multi-az \
  --storage-encrypted
```

### **2. Configuração do CodeBuild**

#### **buildspec.yml**

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/nextcloud
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}

  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$(date +%Y%m%d-%H%M%S)

  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - printf '[{"name":"nextcloud","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
  name: nextcloud-$(date +%Y-%m-%d)
```

### **3. Backup Antes da Migração**

```bash
# Executar script de backup
./backup_migration.sh

# Verificar backup criado
ls -la backup_migration_*/
```

---

## 🖥️ DEPLOY EM EC2

### **1. Configuração da Instância EC2**

#### **User Data Script**

```bash
#!/bin/bash
# User Data Script para EC2

# Atualizar sistema
yum update -y

# Instalar Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Instalar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Instalar PostgreSQL Client
yum install -y postgresql15

# Criar estrutura de diretórios
mkdir -p /opt/nextcloud/{data,config,logs,backups,scripts}
chown -R ec2-user:ec2-user /opt/nextcloud

# Configurar CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Configurar firewall
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

echo "✅ EC2 configurada com sucesso!"
```

### **2. Deploy Automatizado**

#### **Script de Deploy**

```bash
#!/bin/bash
# deploy.sh - Deploy para EC2

set -e

# Configurações
ECR_REGISTRY="380278406175.dkr.ecr.us-east-1.amazonaws.com"
IMAGE_NAME="nextcloud"
EC2_USER="ec2-user"
EC2_HOST="your-ec2-instance.amazonaws.com"
EC2_KEY="your-key.pem"

echo "🚀 Iniciando deploy do Nextcloud..."

# 1. Login ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

# 2. Build e Push
docker build -t $ECR_REGISTRY/$IMAGE_NAME:latest .
docker push $ECR_REGISTRY/$IMAGE_NAME:latest

# 3. Deploy na EC2
ssh -i $EC2_KEY $EC2_USER@$EC2_HOST << 'EOF'
  cd /opt/nextcloud

  # Backup atual
  if [ -f docker-compose.yml ]; then
    docker-compose down
    tar -czf backups/backup-$(date +%Y%m%d-%H%M%S).tar.gz data/ config/
  fi

  # Pull nova imagem
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 380278406175.dkr.ecr.us-east-1.amazonaws.com
  docker pull 380278406175.dkr.ecr.us-east-1.amazonaws.com/nextcloud:latest

  # Iniciar serviços
  docker-compose up -d

  # Verificar status
  sleep 30
  docker-compose ps
  docker-compose logs --tail=20
EOF

echo "✅ Deploy concluído!"
```

### **3. Docker Compose para Produção**

#### **docker-compose.prod.yml**

```yaml
version: "3.8"

services:
  nextcloud:
    image: ${ECR_REGISTRY}/nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - POSTGRES_HOST=${POSTGRES_HOST}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - NEXTCLOUD_ADMIN_USER=${ADMIN_USER}
      - NEXTCLOUD_ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - NEXTCLOUD_TRUSTED_DOMAINS=${TRUSTED_DOMAINS}
      - REDIS_HOST=redis
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    volumes:
      - nextcloud_data:/var/www/html/data
      - nextcloud_config:/var/www/html/config
    depends_on:
      - redis
    networks:
      - nextcloud_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/status.php"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:alpine
    container_name: nextcloud_redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - nextcloud_network

  nginx:
    image: nginx:alpine
    container_name: nextcloud_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - nextcloud_data:/var/www/html/data:ro
    depends_on:
      - nextcloud
    networks:
      - nextcloud_network

volumes:
  nextcloud_data:
  nextcloud_config:
  redis_data:

networks:
  nextcloud_network:
    driver: bridge
```

---

## 📈 AUTO SCALING

### **1. Arquitetura com Auto Scaling**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ALB/NLB       │    │   ASG (EC2)     │    │   RDS PostgreSQL│
│   (Load Balancer)│───▶│   Auto Scaling  │───▶│   (Managed DB)  │
│                 │    │   + Nextcloud   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                       ┌─────────────────┐
                       │   EFS Shared    │
                       │   (File Storage)│
                       └─────────────────┘
```

### **2. Launch Template**

#### **Criação do Launch Template**

```bash
# Criar Launch Template
aws ec2 create-launch-template \
  --launch-template-name nextcloud-template \
  --version-description "Nextcloud v1.0" \
  --launch-template-data '{
    "ImageId": "ami-0c02fb55956c7d316",
    "InstanceType": "t3.medium",
    "KeyName": "your-key-pair",
    "SecurityGroupIds": ["sg-12345"],
    "IamInstanceProfile": {
      "Name": "Nextcloud-EC2-Role"
    },
    "UserData": "'$(base64 -w 0 user-data.sh)'",
    "TagSpecifications": [
      {
        "ResourceType": "instance",
        "Tags": [
          {"Key": "Name", "Value": "Nextcloud-Instance"},
          {"Key": "Environment", "Value": "Production"},
          {"Key": "Application", "Value": "Nextcloud"}
        ]
      }
    ]
  }'
```

### **3. Auto Scaling Group**

#### **Criação do ASG**

```bash
# Criar Auto Scaling Group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name nextcloud-asg \
  --launch-template LaunchTemplateName=nextcloud-template,Version='$Latest' \
  --min-size 1 \
  --max-size 5 \
  --desired-capacity 2 \
  --vpc-zone-identifier "subnet-12345,subnet-67890" \
  --target-group-arns "arn:aws:elasticloadbalancing:us-east-1:123456789:targetgroup/nextcloud-tg/123456789" \
  --health-check-type ELB \
  --health-check-grace-period 300 \
  --termination-policies "OldestInstance" \
  --tags \
    ResourceId=nextcloud-asg,ResourceType=auto-scaling-group,Key=Name,Value=Nextcloud-ASG,PropagateAtLaunch=true \
    ResourceId=nextcloud-asg,ResourceType=auto-scaling-group,Key=Environment,Value=Production,PropagateAtLaunch=true
```

### **4. Scaling Policies**

#### **Scale-Out Policy (CPU)**

```bash
# Criar política de scale-out
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name nextcloud-asg \
  --policy-name nextcloud-scale-out-cpu \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "ScaleOutCooldown": 300,
    "ScaleInCooldown": 600
  }'
```

#### **Scale-Out Policy (Memory)**

```bash
# Criar política de scale-out por memória
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name nextcloud-asg \
  --policy-name nextcloud-scale-out-memory \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "TargetValue": 80.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageMemoryUtilization"
    },
    "ScaleOutCooldown": 300,
    "ScaleInCooldown": 600
  }'
```

#### **Scale-Out Policy (Request Count)**

```bash
# Criar política baseada em requests
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name nextcloud-asg \
  --policy-name nextcloud-scale-out-requests \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "TargetValue": 1000.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ALBRequestCountPerTarget",
      "ResourceLabel": "app/nextcloud-alb/123456789/targetgroup/nextcloud-tg/123456789"
    },
    "ScaleOutCooldown": 300,
    "ScaleInCooldown": 600
  }'
```

### **5. CloudWatch Alarms**

#### **Alarm para CPU Alto**

```bash
# Criar alarm para CPU
aws cloudwatch put-metric-alarm \
  --alarm-name "Nextcloud-High-CPU" \
  --alarm-description "CPU alta no Nextcloud" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions "arn:aws:sns:us-east-1:123456789:nextcloud-alerts"
```

#### **Alarm para Memória Alta**

```bash
# Criar alarm para memória
aws cloudwatch put-metric-alarm \
  --alarm-name "Nextcloud-High-Memory" \
  --alarm-description "Memória alta no Nextcloud" \
  --metric-name MemoryUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions "arn:aws:sns:us-east-1:123456789:nextcloud-alerts"
```

### **6. Application Load Balancer**

#### **Criação do ALB**

```bash
# Criar ALB
aws elbv2 create-load-balancer \
  --name nextcloud-alb \
  --subnets subnet-12345 subnet-67890 \
  --security-groups sg-12345 \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4

# Criar Target Group
aws elbv2 create-target-group \
  --name nextcloud-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-12345 \
  --target-type instance \
  --health-check-path /status.php \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

# Criar Listener
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:123456789:loadbalancer/app/nextcloud-alb/123456789 \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=arn:aws:acm:us-east-1:123456789:certificate/123456789 \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123456789:targetgroup/nextcloud-tg/123456789
```

### **7. EFS para Dados Compartilhados**

#### **Criação do EFS**

```bash
# Criar EFS
aws efs create-file-system \
  --creation-token nextcloud-efs \
  --performance-mode generalPurpose \
  --throughput-mode provisioned \
  --provisioned-throughput-in-mibps 100 \
  --encrypted \
  --tags Key=Name,Value=nextcloud-efs Key=Environment,Value=Production

# Criar Mount Targets
aws efs create-mount-target \
  --file-system-id fs-12345 \
  --subnet-id subnet-12345 \
  --security-groups sg-efs

aws efs create-mount-target \
  --file-system-id fs-12345 \
  --subnet-id subnet-67890 \
  --security-groups sg-efs
```

#### **User Data Script com EFS**

```bash
#!/bin/bash
# User Data Script com EFS para Auto Scaling

# Atualizar sistema
yum update -y

# Instalar Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Instalar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Instalar EFS utils
yum install -y amazon-efs-utils

# Criar diretórios
mkdir -p /opt/nextcloud/{config,logs,backups,scripts}
mkdir -p /mnt/efs/nextcloud

# Montar EFS
echo "fs-12345.efs.us-east-1.amazonaws.com:/ /mnt/efs/nextcloud efs defaults,_netdev" >> /etc/fstab
mount -a

# Configurar permissões
chown -R ec2-user:ec2-user /opt/nextcloud
chown -R ec2-user:ec2-user /mnt/efs/nextcloud

# Configurar CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Configurar firewall
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Criar script de inicialização
cat > /opt/nextcloud/scripts/start-nextcloud.sh << 'EOF'
#!/bin/bash
cd /opt/nextcloud

# Carregar variáveis de ambiente
source .env

# Fazer login no ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Pull da imagem mais recente
docker pull $ECR_REGISTRY/nextcloud:latest

# Parar containers existentes
docker-compose down

# Iniciar serviços
docker-compose up -d

# Verificar status
sleep 30
docker-compose ps
EOF

chmod +x /opt/nextcloud/scripts/start-nextcloud.sh
chown ec2-user:ec2-user /opt/nextcloud/scripts/start-nextcloud.sh

echo "✅ EC2 configurada com EFS e Auto Scaling!"
```

### **8. Docker Compose para Auto Scaling**

#### **docker-compose.asg.yml**

```yaml
version: "3.8"

services:
  nextcloud:
    image: ${ECR_REGISTRY}/nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - "80:8080"
    environment:
      - POSTGRES_HOST=${POSTGRES_HOST}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - NEXTCLOUD_ADMIN_USER=${ADMIN_USER}
      - NEXTCLOUD_ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - NEXTCLOUD_TRUSTED_DOMAINS=${TRUSTED_DOMAINS}
      - NEXTCLOUD_DATADIR=/var/www/html/data
      - REDIS_HOST=redis
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    volumes:
      - /mnt/efs/nextcloud/data:/var/www/html/data
      - /opt/nextcloud/config:/var/www/html/config
    depends_on:
      - redis
    networks:
      - nextcloud_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/status.php"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  redis:
    image: redis:alpine
    container_name: nextcloud_redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - nextcloud_network

  nginx:
    image: nginx:alpine
    container_name: nextcloud_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - /mnt/efs/nextcloud/data:/var/www/html/data:ro
    depends_on:
      - nextcloud
    networks:
      - nextcloud_network

volumes:
  redis_data:
    driver: local

networks:
  nextcloud_network:
    driver: bridge
```

### **9. Configuração de Health Checks**

#### **Health Check Script**

```bash
#!/bin/bash
# /opt/nextcloud/scripts/health-check.sh

cd /opt/nextcloud

# Verificar containers
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Containers não estão rodando!"
    exit 1
fi

# Verificar Nextcloud
if ! curl -f http://localhost/status.php > /dev/null 2>&1; then
    echo "❌ Nextcloud não está respondendo!"
    exit 1
fi

# Verificar EFS mount
if ! mountpoint -q /mnt/efs/nextcloud; then
    echo "❌ EFS não está montado!"
    exit 1
fi

# Verificar espaço em disco
DISK_USAGE=$(df /opt/nextcloud | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "⚠️ Espaço em disco baixo: ${DISK_USAGE}%"
fi

echo "✅ Sistema saudável!"
```

### **10. Lifecycle Hooks**

#### **Configuração de Lifecycle Hooks**

```bash
# Lifecycle hook para scale-out
aws autoscaling put-lifecycle-hook \
  --auto-scaling-group-name nextcloud-asg \
  --lifecycle-hook-name nextcloud-scale-out \
  --lifecycle-transition autoscaling:EC2_INSTANCE_LAUNCHING \
  --default-result CONTINUE \
  --heartbeat-timeout 300

# Lifecycle hook para scale-in
aws autoscaling put-lifecycle-hook \
  --auto-scaling-group-name nextcloud-asg \
  --lifecycle-hook-name nextcloud-scale-in \
  --lifecycle-transition autoscaling:EC2_INSTANCE_TERMINATING \
  --default-result CONTINUE \
  --heartbeat-timeout 300
```

### **11. Scripts de Lifecycle**

#### **Scale-Out Script**

```bash
#!/bin/bash
# /opt/nextcloud/scripts/scale-out.sh

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
LIFECYCLE_HOOK_NAME="nextcloud-scale-out"
ASG_NAME="nextcloud-asg"

# Aguardar Nextcloud estar pronto
echo "Aguardando Nextcloud estar pronto..."
while ! curl -f http://localhost/status.php > /dev/null 2>&1; do
    sleep 10
done

# Notificar que a instância está pronta
aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name $LIFECYCLE_HOOK_NAME \
  --auto-scaling-group-name $ASG_NAME \
  --lifecycle-action-result CONTINUE \
  --instance-id $INSTANCE_ID

echo "✅ Instância pronta para receber tráfego!"
```

#### **Scale-In Script**

```bash
#!/bin/bash
# /opt/nextcloud/scripts/scale-in.sh

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
LIFECYCLE_HOOK_NAME="nextcloud-scale-in"
ASG_NAME="nextcloud-asg"

# Parar containers graciosamente
echo "Parando containers graciosamente..."
docker-compose down

# Aguardar conexões terminarem
sleep 30

# Notificar que a instância pode ser terminada
aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name $LIFECYCLE_HOOK_NAME \
  --auto-scaling-group-name $ASG_NAME \
  --lifecycle-action-result CONTINUE \
  --instance-id $INSTANCE_ID

echo "✅ Instância pronta para ser terminada!"
```

### **12. Monitoramento do Auto Scaling**

#### **CloudWatch Dashboard**

```bash
# Criar dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "Nextcloud-AutoScaling" \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "x": 0,
        "y": 0,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", "nextcloud-asg"],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", "nextcloud-asg"],
            ["AWS/AutoScaling", "GroupTotalInstances", "AutoScalingGroupName", "nextcloud-asg"]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-east-1",
          "title": "Auto Scaling Group Capacity",
          "period": 300
        }
      },
      {
        "type": "metric",
        "x": 12,
        "y": 0,
        "width": 12,
        "height": 6,
        "properties": {
          "metrics": [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "nextcloud-asg"],
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", "nextcloud-asg"],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", "nextcloud-asg"]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-east-1",
          "title": "EC2 Metrics",
          "period": 300
        }
      }
    ]
  }'
```

### **13. Configuração de Notificações**

#### **SNS Topic para Alertas**

```bash
# Criar SNS Topic
aws sns create-topic --name nextcloud-alerts

# Criar subscription
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789:nextcloud-alerts \
  --protocol email \
  --notification-endpoint seu-email@empresa.com
```

---

## 🔧 CONFIGURAÇÃO DE PRODUÇÃO

### **1. Configuração Nginx**

#### **nginx.conf**

```nginx
upstream nextcloud {
    server nextcloud:8080;
}

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Performance
    client_max_body_size 10G;
    client_body_timeout 60s;
    client_header_timeout 60s;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    location / {
        proxy_pass http://nextcloud;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600;
        proxy_connect_timeout 3600;
        proxy_send_timeout 3600;
    }
}
```

### **2. Configuração de Segurança**

#### **Security Groups**

```yaml
Nextcloud-SG:
  Inbound:
    - HTTP: 80 (0.0.0.0/0)
    - HTTPS: 443 (0.0.0.0/0)
    - SSH: 22 (seu-ip/32)
  Outbound:
    - All Traffic: 0.0.0.0/0

Database-SG:
  Inbound:
    - PostgreSQL: 5432 (Nextcloud-SG)
  Outbound:
    - All Traffic: 0.0.0.0/0
```

#### **IAM Role para EC2**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue", "rds:DescribeDBInstances"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

### **3. Configuração de Backup**

#### **Script de Backup Automático**

```bash
#!/bin/bash
# /opt/nextcloud/scripts/backup.sh

BACKUP_DIR="/opt/nextcloud/backups"
DATE=$(date +%Y%m%d-%H%M%S)
S3_BUCKET="your-nextcloud-backups"

cd /opt/nextcloud

# Backup dados Nextcloud
echo "📦 Backup dados Nextcloud..."
docker-compose exec -T nextcloud tar -czf - /var/www/html/data > $BACKUP_DIR/nextcloud-data-$DATE.tar.gz

# Backup banco de dados
echo "🗄️ Backup banco de dados..."
docker-compose exec -T db pg_dump -U nextcloud nextcloud > $BACKUP_DIR/nextcloud-db-$DATE.sql

# Upload S3
echo "☁️ Upload para S3..."
aws s3 cp $BACKUP_DIR/nextcloud-data-$DATE.tar.gz s3://$S3_BUCKET/data/
aws s3 cp $BACKUP_DIR/nextcloud-db-$DATE.sql s3://$S3_BUCKET/database/

# Limpeza local
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete

echo "✅ Backup concluído!"
```

---

## 💾 BACKUP E RESTORE

### **1. Backup Manual**

```bash
# Backup completo
./backup_migration.sh

# Backup específico
docker-compose exec db pg_dump -U nextcloud nextcloud > backup-$(date +%Y%m%d).sql
```

### **2. Restore Manual**

```bash
# Restore banco
docker-compose exec -T db psql -U nextcloud nextcloud < backup-20240101.sql

# Restore dados
docker-compose exec nextcloud tar -xzf backup-data.tar.gz -C /
```

### **3. Migração Entre Ambientes**

#### **Usando Scripts Integrados do Docker**

**Backup:**

```bash
# Backup usando script integrado
docker-compose exec nextcloud backup-database.sh -o /opt/backups/migration_backup.dump --compress

# Copiar backup para host
docker cp $(docker-compose ps -q nextcloud):/opt/backups/migration_backup.dump ./migration_backup.dump
```

**Restore:**

```bash
# Copiar backup para container
docker cp ./migration_backup.dump $(docker-compose ps -q nextcloud):/opt/restores/

# Restore usando script integrado
docker-compose exec nextcloud restore-database.sh -f /opt/restores/migration_backup.dump --force
```

#### **backup_restore_exemplo.sh (Método Tradicional)**

```bash
#!/bin/bash

# Configurações
PGHOST_LOCAL="localhost"
PGPORT_LOCAL="5432"
PGUSER_LOCAL="nextcloud"
PGDATABASE_LOCAL="nextcloud"

PGHOST_RDS="your-rds-endpoint.region.rds.amazonaws.com"
PGPORT_RDS="5432"
PGUSER_RDS="postgres"
PGDATABASE_RDS="nextcloud"

DUMP_FILE="nextcloud_dump.sql"

# Dump local
echo "Fazendo dump do banco local..."
pg_dump -h $PGHOST_LOCAL -p $PGPORT_LOCAL -U $PGUSER_LOCAL -d $PGDATABASE_LOCAL -F c -b -v -f $DUMP_FILE

# Drop e recriar banco remoto
psql -h $PGHOST_RDS -U $PGUSER_RDS <<EOF
DROP DATABASE IF EXISTS $PGDATABASE_RDS;
CREATE DATABASE $PGDATABASE_RDS;
EOF

# Restore remoto
echo "Restaurando no RDS..."
pg_restore --no-owner --no-acl -h $PGHOST_RDS -p $PGPORT_RDS -U $PGUSER_RDS -d $PGDATABASE_RDS -v $DUMP_FILE

echo "✅ Migração concluída!"
```

### **4. Restore Automático no Deploy**

#### **Usando Variáveis de Ambiente**

**docker-compose.yml com Restore:**

```yaml
services:
  nc:
    build: .
    environment:
      - POSTGRES_HOST=db
      - POSTGRES_PASSWORD=nextcloud
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - RESTORE_BACKUP_FILE=/opt/restores/initial_backup.dump
      - CREATE_INITIAL_BACKUP=true
    volumes:
      - ./backups:/opt/restores:ro
      - nc_data:/var/www/html
    depends_on:
      - db
```

**Deploy com Restore:**

```bash
# 1. Preparar backup
cp backup.dump ./backups/initial_backup.dump

# 2. Deploy com restore automático
docker-compose up -d

# 3. Verificar restore
docker-compose logs nc | grep "Restore"
```

#### **Opções Avançadas de Restore**

```bash
# Restore com backup de segurança
docker-compose exec nextcloud restore-database.sh \
  -f /opt/restores/backup.dump \
  --backup-before-restore \
  --verbose

# Restore apenas schema
docker-compose exec nextcloud restore-database.sh \
  -f /opt/restores/schema_only.sql \
  --schema-only

# Restore apenas dados
docker-compose exec nextcloud restore-database.sh \
  -f /opt/restores/data_only.dump \
  --data-only

# Simular restore (dry-run)
docker-compose exec nextcloud restore-database.sh \
  -f /opt/restores/backup.dump \
  --dry-run \
  --verbose
```

#### **Backup Avançado**

```bash
# Backup com compressão
docker-compose exec nextcloud backup-database.sh \
  -o /opt/backups/backup_$(date +%Y%m%d).dump \
  --compress \
  --verbose

# Backup apenas schema
docker-compose exec nextcloud backup-database.sh \
  -o /opt/backups/schema_backup.sql \
  -f sql \
  --schema-only

# Backup com limpeza automática
docker-compose exec nextcloud backup-database.sh \
  --cleanup-days 7 \
  --compress
```

---

## 📊 MONITORAMENTO

### **1. CloudWatch Configuration**

```json
{
  "agent": {
    "metrics_collection_interval": 60
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/nextcloud/logs/nextcloud.log",
            "log_group_name": "/aws/ec2/nextcloud/app"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "Nextcloud/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user"]
      },
      "disk": {
        "measurement": ["used_percent"]
      },
      "mem": {
        "measurement": ["mem_used_percent"]
      }
    }
  }
}
```

### **2. Health Checks**

```bash
#!/bin/bash
# /opt/nextcloud/scripts/health-check.sh

cd /opt/nextcloud

# Verificar containers
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Containers não estão rodando!"
    exit 1
fi

# Verificar Nextcloud
if ! curl -f http://localhost/status.php > /dev/null 2>&1; then
    echo "❌ Nextcloud não está respondendo!"
    exit 1
fi

# Verificar espaço em disco
DISK_USAGE=$(df /opt/nextcloud | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "⚠️ Espaço em disco baixo: ${DISK_USAGE}%"
fi

echo "✅ Sistema saudável!"
```

### **3. Alertas CloudWatch**

```yaml
Alarmas:
  - CPU > 80% por 5 minutos
  - Memory > 85% por 5 minutos
  - Disk Space > 90% por 2 minutos
  - Application Health Check falha
```

---

## 🐛 TROUBLESHOOTING

### **1. Problemas Comuns**

#### **Container não inicia**

```bash
# Verificar logs
docker-compose logs nextcloud

# Verificar configuração
docker-compose config

# Verificar recursos
docker stats

# Verificar se a imagem foi construída corretamente
docker images nextcloud-custom

# Verificar layers da imagem
docker history nextcloud-custom:latest
```

#### **Problemas com Dockerfile**

```bash
# Build falha
docker build --no-cache -t nextcloud-custom:latest .

# Verificar se todos os arquivos estão presentes
ls -la init-migration.sh restore-database.sh backup-database.sh

# Verificar permissões dos scripts
chmod +x init-migration.sh restore-database.sh backup-database.sh

# Build com verbose output
docker build --progress=plain -t nextcloud-custom:latest .
```

#### **Problemas com Scripts Integrados**

```bash
# Verificar se scripts estão no container
docker-compose exec nextcloud ls -la /usr/local/bin/ | grep -E "(init-migration|restore-database|backup-database)"

# Executar script manualmente
docker-compose exec nextcloud /usr/local/bin/init-migration.sh

# Verificar permissões dos scripts no container
docker-compose exec nextcloud ls -la /usr/local/bin/init-migration.sh

# Verificar diretórios de backup/restore
docker-compose exec nextcloud ls -la /opt/backups /opt/restores
```

#### **Migrações falham**

```bash
# Verificar conectividade banco
docker-compose exec nextcloud pg_isready -h db

# Executar migrações manualmente
docker-compose exec nextcloud /usr/local/bin/init-migration.sh

# Verificar logs banco
docker-compose logs db
```

#### **Permissões incorretas**

```bash
# Corrigir ownership
docker-compose exec nextcloud chown -R www-data:www-data /var/www/html

# Verificar volumes
docker volume ls
docker volume inspect nextcloud_data
```

### **2. Comandos de Debug**

```bash
# Acessar container
docker-compose exec nextcloud bash

# Verificar banco
docker-compose exec nextcloud psql -h db -U nextcloud -d nextcloud

# Verificar configuração Nextcloud
docker-compose exec nextcloud php occ config:list

# Verificar logs sistema
journalctl -u docker
```

### **3. Logs Importantes**

```bash
# Logs aplicação
/opt/nextcloud/logs/nextcloud.log

# Logs sistema
/var/log/messages
/var/log/user-data.log

# Logs Docker
docker-compose logs
```

---

## 🔧 MANUTENÇÃO

### **1. Atualizações**

```bash
# Atualizar sistema
sudo yum update -y

# Atualizar containers
docker-compose pull
docker-compose up -d

# Limpeza Docker
docker system prune -f
docker volume prune -f

# Rebuild da imagem personalizada
docker build --no-cache -t nextcloud-custom:latest .
docker-compose up -d --build
```

### **1.1. Manutenção do Dockerfile**

#### **Atualização da Imagem Base**

```bash
# Verificar versões disponíveis da imagem base
docker search nextcloud

# Atualizar Dockerfile para nova versão
# Editar: FROM nextcloud:apache -> FROM nextcloud:apache-version

# Rebuild com nova versão
docker build --no-cache -t nextcloud-custom:latest .
```

#### **Otimização de Build**

```bash
# Build com cache multi-stage
docker buildx build \
  --platform linux/amd64 \
  --cache-from type=local,src=/tmp/.buildx-cache \
  --cache-to type=local,dest=/tmp/.buildx-cache \
  -t nextcloud-custom:latest .

# Verificar tamanho da imagem
docker images nextcloud-custom
docker history nextcloud-custom:latest
```

#### **Limpeza de Imagens**

```bash
# Remover imagens antigas
docker image prune -a

# Remover imagens específicas
docker rmi nextcloud-custom:old-tag

# Limpeza completa do sistema
docker system prune -a --volumes
```

### **2. Backup de Manutenção**

```bash
# Backup antes atualização
./scripts/backup.sh

# Verificar integridade
docker-compose exec db pg_dump -U nextcloud nextcloud > verify-backup.sql
```

### **3. Monitoramento Contínuo**

```bash
# Verificar saúde
./scripts/health-check.sh

# Verificar recursos
htop
docker stats

# Verificar logs
tail -f /opt/nextcloud/logs/nextcloud.log
```

---

## 📞 SUPORTE

### **Contatos**

- **Desenvolvedor**: [Seu Nome]
- **Email**: [seu-email@empresa.com]
- **Telefone**: [seu-telefone]

### **Recursos**

- **Documentação Nextcloud**: https://docs.nextcloud.com/
- **AWS Documentation**: https://docs.aws.amazon.com/
- **Docker Documentation**: https://docs.docker.com/

### **Logs de Suporte**

```bash
# Coletar logs para suporte
tar -czf support-logs-$(date +%Y%m%d).tar.gz \
  /opt/nextcloud/logs/ \
  /var/log/messages \
  /var/log/user-data.log \
  docker-compose.yml \
  .env
```

---

**Última Atualização**: $(date +%Y-%m-%d)
**Versão da Documentação**: 1.0.0
**Responsável**: Equipe de DevOps
