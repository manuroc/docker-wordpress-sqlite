#!/bin/bash

# terminate on errors
set -e

# Check if volume is empty
if [ ! -f "/var/www/wp-content/db.php" ]; then
    echo 'Setting up wp-content volume'
    # Copy wp-content from Wordpress src to volume
    cp -r /usr/src/wordpress/wp-content /var/www/
    chown -R nobody:nobody /var/www
fi

# Fix ownership
chown -R nobody:nobody /var/www/wp-content

# Directories need execute bit to be traversable
find /var/www/wp-content -type d -exec chmod 755 {} \;

# Files readable/writable by owner only
find /var/www/wp-content -type f -exec chmod 644 {} \;

# Lock down the database directory specifically
chmod 700 /var/www/wp-content/database
chmod 600 /var/www/wp-content/database/.ht.sqlite

# Check if wp-secrets.php exists
if ! [ -f "/var/www/wp-content/wp-secrets.php" ]; then
    echo '<?php' > /var/www/wp-content/wp-secrets.php
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
        # Generate secrets
        curl -f https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/wp-content/wp-secrets.php
    fi
fi
exec "$@"
