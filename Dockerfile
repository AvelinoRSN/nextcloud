FROM nextcloud:apache

# Dependências adicionais
RUN apt-get update && apt-get install -y \
    imagemagick \
    ffmpeg \
    mariadb-client \
    redis-tools \
    ghostscript \
    libreoffice \
    && rm -rf /var/lib/apt/lists/*

# Ajustes PHP para uploads grandes
RUN echo 'upload_max_filesize = 2G' >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo 'post_max_size = 2G' >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo 'memory_limit = 512M' >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo 'max_execution_time = 300' >> /usr/local/etc/php/conf.d/uploads.ini

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
