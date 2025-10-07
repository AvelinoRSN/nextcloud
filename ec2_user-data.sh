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

# Instalar Git
yum install -y git

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

echo " EC2 configurada com sucesso!"
```

### **2. Deploy Automatizado**

#### **Script de Deploy**
