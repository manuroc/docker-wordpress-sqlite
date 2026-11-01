FROM alpine:3.24

# Build arguments for OCI annotations
ARG BUILD_DATE
ARG VERSION
ARG VCS_REF

# OCI annotations
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="Tim de Pater <code@trafex.nl>"
LABEL org.opencontainers.image.url="https://github.com/TrafeX/docker-wordpress"
LABEL org.opencontainers.image.documentation="https://github.com/TrafeX/docker-wordpress"
LABEL org.opencontainers.image.source="https://github.com/TrafeX/docker-wordpress"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="TrafeX"
LABEL org.opencontainers.image.title="WordPress with Nginx 1.30 & PHP-FPM 8.5"
LABEL org.opencontainers.image.description="Lightweight WordPress container with Nginx 1.30 & PHP-FPM 8.5 based on Alpine Linux."

# Install packages
RUN apk --no-cache add \
  'php85>=8.5.12' \
  'php85-fpm>=8.5.12' \
  php85-mysqli \
  php85-json \
  php85-openssl \
  php85-curl \
  php85-zlib \
  php85-xml \
  php85-phar \
  php85-intl \
  php85-dom \
  php85-xmlreader \
  php85-xmlwriter \
  php85-exif \
  php85-fileinfo \
  php85-sodium \
  php85-gd \
  php85-simplexml \
  php85-ctype \
  php85-mbstring \
  php85-zip \
  php85-iconv \
  php85-pecl-imagick \
  php85-session \
  php85-tokenizer \
  php85-sqlite3 \
  php85-pecl-apcu \
  php85-pdo_sqlite \
  php85-pecl-igbinary \
  nginx \
  supervisor \
  curl \
  bash \
  less \
  unzip

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/security-headers.conf /etc/nginx/security-headers.conf

# Directory for the nginx FastCGI page cache (nginx workers run as the nginx user)
RUN mkdir -p /var/cache/nginx/fastcgi \
  && chown -R nginx:nginx /var/cache/nginx

# Configure PHP-FPM
# Maximum number of simultaneous PHP workers, size it to the container's RAM (see config/fpm-pool.conf)
ENV PHP_FPM_MAX_CHILDREN=20
COPY config/fpm-pool.conf /etc/php85/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php85/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# wp-content volume
VOLUME /var/www/wp-content
WORKDIR /var/www/wp-content
RUN chown -R nobody:nobody /var/www

# WordPress
ENV WORDPRESS_VERSION=7.1.3
ENV WORDPRESS_SHA1=491a78c7676b15dffcc69130c6054b8f49228a91

RUN mkdir -p /usr/src

# Upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
RUN curl -o wordpress.tar.gz -SL https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz \
  && echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
  && tar -xzf wordpress.tar.gz -C /usr/src/ \
  && rm wordpress.tar.gz \
  && chown -R nobody:nobody /usr/src/wordpress

# Add SQLite DB plugin
RUN curl -o sqlite.zip -SL https://downloads.wordpress.org/plugin/sqlite-database-integration.3.1.2.zip \
  && unzip sqlite.zip -d /usr/src/wordpress/wp-content/plugins \
  && cp /usr/src/wordpress/wp-content/plugins/sqlite-database-integration/db.copy /usr/src/wordpress/wp-content/db.php \
  && rm sqlite.zip \
  && chown -R nobody:nobody /usr/src/wordpress/wp-content/plugins/sqlite-database-integration \
  && chown nobody:nobody /usr/src/wordpress/wp-content/db.php

# Add atec Cache APCu plugin and install its persistent object cache drop-in.
# The plugin normally builds wp-content/object-cache.php when the object cache is enabled in its settings;
# the same thing is done here at build time (driver inserted into the drop-in template, as the plugin does).
RUN curl -o atec-cache-apcu.zip -SL https://downloads.wordpress.org/plugin/atec-cache-apcu.2.3.77.zip \
  && unzip atec-cache-apcu.zip -d /usr/src/wordpress/wp-content/plugins \
  && rm atec-cache-apcu.zip \
  && php85 -r '$d = "/usr/src/wordpress/wp-content/plugins/atec-cache-apcu/install/"; \
       $driver = str_replace(["<?php\n", ">?"], "", file_get_contents($d . "object-cache-driver.inc")); \
       file_put_contents("/usr/src/wordpress/wp-content/object-cache.php", str_replace("/* OC INSERT DRIVER */", $driver, file_get_contents($d . "object-cache.php")));' \
  && grep -q ATEC_OC_ACTIVE_APCU /usr/src/wordpress/wp-content/object-cache.php \
  && php85 -l /usr/src/wordpress/wp-content/object-cache.php \
  && chown -R nobody:nobody /usr/src/wordpress/wp-content/plugins/atec-cache-apcu \
  && chown nobody:nobody /usr/src/wordpress/wp-content/object-cache.php

# Add WP CLI
ENV WP_CLI_CONFIG_PATH=/usr/src/wordpress/wp-cli.yml
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  && chmod +x /usr/local/bin/wp
COPY --chown=nobody:nobody wp-cli.yml /usr/src/wordpress/

# WP config
COPY --chown=nobody:nobody wp-config.php /usr/src/wordpress
RUN chmod 640 /usr/src/wordpress/wp-config.php

# Link wp-secrets to location on wp-content
RUN ln -s /var/www/wp-content/wp-secrets.php /usr/src/wordpress/wp-secrets.php

# Entrypoint to copy wp-content
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Checks nginx and PHP-FPM through the lightweight FPM ping endpoint (no WordPress/SQLite bootstrap)
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping
