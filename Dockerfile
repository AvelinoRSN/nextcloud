# Dockerfile unificado para Nextcloud com migrações e restore
FROM nextcloud:apache

# Instalar dependências necessárias
RUN apt-get update && apt-get install -y \
    postgresql-client \
    curl \
    wget \
    unzip \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Copiar scripts de migração, restore e auto-instalação
COPY init-migration.sh /usr/local/bin/
COPY restore-database.sh /usr/local/bin/
COPY backup-database.sh /usr/local/bin/
COPY auto-install.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-migration.sh \
    && chmod +x /usr/local/bin/restore-database.sh \
    && chmod +x /usr/local/bin/backup-database.sh \
    && chmod +x /usr/local/bin/auto-install.sh

# Criar diretórios para backups e restores
RUN mkdir -p /opt/backups \
    && mkdir -p /opt/restores \
    && chmod 755 /opt/backups \
    && chmod 755 /opt/restores

# Definir permissões corretas preservando timestamps
RUN chown -R www-data:www-data /var/www/html

# Expor porta 80
EXPOSE 80

# Script de inicialização com migrações, restore e auto-instalação
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
