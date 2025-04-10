FROM alpine:3.21
LABEL Maintainer="Tim de Pater <code@trafex.nl>" \
  Description="Lightweight WordPress container with Nginx 1.26 & PHP-FPM 8.4 based on Alpine Linux."

# Install packages
RUN apk --no-cache add \
  php84 \
  php84-fpm \
  php84-mysqli \
  php84-json \
  php84-openssl \
  php84-curl \
  php84-zlib \
  php84-xml \
  php84-phar \
  php84-intl \
  php84-dom \
  php84-xmlreader \
  php84-xmlwriter \
  php84-exif \
  php84-fileinfo \
  php84-sodium \
  php84-gd \
  php84-simplexml \
  php84-ctype \
  php84-mbstring \
  php84-zip \
  php84-opcache \
  php84-iconv \
  php84-pecl-imagick \
  php84-session \
  php84-tokenizer \
  php84-sqlite3 \
  php84-pecl-redis \
  php84-pdo_sqlite \
  nginx \
  supervisor \
  curl \
  bash \
  less

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php84/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php84/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN ln -s /usr/bin/php84 /usr/bin/php

# wp-content volume
VOLUME /var/www/wp-content
WORKDIR /var/www/wp-content
RUN chown -R nobody:nobody /var/www

# WordPress
ENV WORDPRESS_VERSION 6.7.2
ENV WORDPRESS_SHA1 ff727df89b694749e91e357dc2329fac620b3906

RUN mkdir -p /usr/src

# Upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
RUN curl -o wordpress.tar.gz -SL https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz \
  && echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
  && tar -xzf wordpress.tar.gz -C /usr/src/ \
  && rm wordpress.tar.gz \
  && chown -R nobody:nobody /usr/src/wordpress

# Add SQLite plugin
RUN curl -o sqlite.tar.gz -SL https://github.com/WordPress/sqlite-database-integration/archive/refs/tags/v2.1.16.tar.gz \
  && tar -xzf sqlite.tar.gz -C /usr/src/wordpress/wp-content/plugins \
  && mv /usr/src/wordpress/wp-content/plugins/sqlite-database-integration-2.1.16 /usr/src/wordpress/wp-content/plugins/sqlite-database-integration \
  && cp /usr/src/wordpress/wp-content/plugins/sqlite-database-integration/db.copy /usr/src/wordpress/wp-content/db.php
  && rm sqlite.tar.gz \
  && chown -R nobody:nobody /usr/src/wordpress/wp-content/plugins/sqlite-database-integration
  && chown nobody:nobody /usr/src/wordpress/wp-content/db.php

# Add redis plugin
RUN curl -o redis.tar.gz -SL https://github.com/rhubarbgroup/redis-cache/archive/refs/tags/2.5.4.tar.gz \
  && tar -xzf redis.tar.gz -C /usr/src/wordpress/wp-content/plugins \
  && mv /usr/src/wordpress/wp-content/plugins/redis-cache-2.5.4 /usr/src/wordpress/wp-content/plugins/redis-cache \
  && rm redis.tar.gz \
  && chown -R nobody:nobody /usr/src/wordpress/wp-content/plugins/redis-cache

# Add WP CLI
ENV WP_CLI_CONFIG_PATH /usr/src/wordpress/wp-cli.yml
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

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/wp-login.php
