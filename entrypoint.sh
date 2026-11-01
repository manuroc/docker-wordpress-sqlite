#!/bin/bash

# terminate on errors
set -e

WP_CONTENT=/var/www/wp-content
DB_DIR="$WP_CONTENT/database"

# Check if volume is empty
if [ ! -f "$WP_CONTENT/db.php" ]; then
    echo 'Setting up wp-content volume'
    # Copy wp-content from Wordpress src to volume
    cp -r /usr/src/wordpress/wp-content /var/www/
    chown -R nobody:nobody /var/www
fi

# Only touch ownership and permissions of paths that are not already correct, instead of
# rewriting everything on every start (slow on large media libraries). The database
# directory is handled separately below.
#
# Ownership
find "$WP_CONTENT" \( ! -user nobody -o ! -group nobody \) -exec chown nobody:nobody {} +
# Directories need execute bit to be traversable
find "$WP_CONTENT" -path "$DB_DIR" -prune -o -type d ! -perm 755 -exec chmod 755 {} +
# Files readable/writable by owner only
find "$WP_CONTENT" -path "$DB_DIR" -prune -o -type f ! -perm 644 -exec chmod 644 {} +

# Lock down the database directory specifically
if [ -d "$DB_DIR" ]; then
    chmod 700 "$DB_DIR"
    # Includes the -wal and -shm files SQLite creates next to the database
    find "$DB_DIR" -type f ! -perm 600 -exec chmod 600 {} +
fi

# Generate a random alphanumeric string of the given length, without external services
random_string() {
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "${1:-64}"
}

# Check if wp-secrets.php exists
if ! [ -f "$WP_CONTENT/wp-secrets.php" ]; then
    echo '<?php' > "$WP_CONTENT/wp-secrets.php"
    # Check that secrets environment variables are not set
    if [ ! $AUTH_KEY ] \
    && [ ! $SECURE_AUTH_KEY ] \
    && [ ! $LOGGED_IN_KEY ] \
    && [ ! $NONCE_KEY ] \
    && [ ! $AUTH_SALT ] \
    && [ ! $SECURE_AUTH_SALT ] \
    && [ ! $LOGGED_IN_SALT ] \
    && [ ! $NONCE_SALT ]; then
        echo "Generating wp-secrets.php"
        # Generate secrets locally
        for name in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
            echo "define('$name', '$(random_string 64)');" >> "$WP_CONTENT/wp-secrets.php"
        done
    fi
    chown nobody:nobody "$WP_CONTENT/wp-secrets.php"
fi
exec "$@"
