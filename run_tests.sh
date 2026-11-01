#!/usr/bin/env sh
apk --no-cache add curl
for i in $(seq 1 10); do curl -fs wordpress > /dev/null && break || { echo -n '.'; sleep 1; }; done;
curl --silent --fail http://wordpress/wp-admin/install.php | grep 'wp-core-ui'

# Security headers are set by nginx
curl --silent --fail --head http://wordpress/wp-admin/install.php | grep -i '^x-content-type-options: nosniff'
