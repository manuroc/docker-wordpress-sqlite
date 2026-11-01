#!/bin/sh
# Checks that run inside the running container, see the "Check image internals" step in
# .github/workflows/build.yaml:  docker compose -f docker-compose.test.yml exec -T wordpress sh -s < run_image_checks.sh
set -eu

check() {
    description=$1
    shift
    if "$@" > /dev/null 2>&1; then
        echo "ok   - $description"
    else
        echo "FAIL - $description"
        failed=1
    fi
}

failed=0

check "nginx configuration is valid"            nginx -t
check "php-fpm answers on /fpm-ping"            sh -c 'curl --silent --fail http://127.0.0.1/fpm-ping | grep -q pong'
check "SQLite db.php drop-in is installed"      test -f /var/www/wp-content/db.php
check "APCu object-cache.php drop-in installed" grep -q ATEC_OC_ACTIVE_APCU /var/www/wp-content/object-cache.php
check "apcu extension is loaded"                php85 -r 'exit(extension_loaded("apcu") ? 0 : 1);'
check "pdo_sqlite extension is loaded"          php85 -r 'exit(extension_loaded("pdo_sqlite") ? 0 : 1);'
check "igbinary extension is loaded"            php85 -r 'exit(extension_loaded("igbinary") ? 0 : 1);'
check "OPcache is available"                    php85 -r 'exit(function_exists("opcache_get_status") ? 0 : 1);'
check "database directory is blocked in nginx"  sh -c 'nginx -T 2>/dev/null | grep -qF "location ^~ /wp-content/database/"'
check "page cache directory is writable by nginx" su -s /bin/sh nginx -c 'test -w /var/cache/nginx/fastcgi'

exit "$failed"
