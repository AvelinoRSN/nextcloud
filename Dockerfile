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
