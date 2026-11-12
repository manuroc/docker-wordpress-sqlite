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

# Keep the bundled plugins in step with the image. The volume only gets them the first time, and a restore that replaces the
# plugins folder (for example UpdraftPlus restoring a backup of another site) would remove them and break the database layer.
# A bundled plugin is copied in when it is missing or older than the image's version; a newer one is never touched.
plugin_version() {
    sed -n 's/^[[:space:]*]*Version:[[:space:]]*//p' "$1" 2> /dev/null | head -n 1 | tr -d '\r[:space:]'
}
sync_plugin() {
    slug=$1 main=$2 required=$3
    src="/usr/src/wordpress/wp-content/plugins/$slug"
    dst="$WP_CONTENT/plugins/$slug"
    [ -f "$src/$main" ] || return 0
    new=$(plugin_version "$src/$main")
    old=$(plugin_version "$dst/$main")
    if [ -z "$old" ]; then
        [ "$required" = yes ] || return 0
    elif ! php85 -r 'exit(version_compare($argv[1], $argv[2], "<") ? 0 : 1);' "$old" "$new"; then
        return 0
    fi
    echo "Installing bundled plugin $slug $new (volume had: ${old:-nothing})"
    mkdir -p "$WP_CONTENT/plugins"
    rm -rf "$dst"
    cp -r "$src" "$dst"
}
sync_plugin sqlite-database-integration load.php yes
sync_plugin atec-cache-apcu atec-cache-apcu.php yes
# The db.php drop-in must be the one that loads the SQLite plugin. It is put back when it is missing, or when another plugin's db.php
# (for example Query Monitor's, which may arrive with a restored backup of another site) replaced it. The other file is kept as db.php.other.
dropin_source="$WP_CONTENT/plugins/sqlite-database-integration/db.copy"
if [ -f "$dropin_source" ]; then
    if [ -f "$WP_CONTENT/db.php" ] && ! grep -q SQLITE_DB_DROPIN_VERSION "$WP_CONTENT/db.php"; then
        echo "db.php is not the SQLite drop-in; keeping it as db.php.other and restoring the SQLite one"
        mv "$WP_CONTENT/db.php" "$WP_CONTENT/db.php.other"
    fi
    [ -f "$WP_CONTENT/db.php" ] || cp "$dropin_source" "$WP_CONTENT/db.php"
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
