# WordPress Docker Container

Lightweight WordPress container with Nginx 1.30 & PHP-FPM 8.5 based on Alpine Linux.

Uses SQLite for database storage for speed and portability. No separate MySQL or MariaDB container necessary.

Extra PHP extensions have also been added for performance, such as APCu.

_WordPress version currently installed:_ **7.1.3**

- Can be used in production
- Optimized for 100 concurrent users
- Optimized to only use resources when there's traffic (by using PHP-FPM's ondemand PM)
- Works with Amazon Cloudfront or CloudFlare as SSL terminator and CDN
- Multi-platform, supporting AMD64 and ARM64
- Built on the lightweight Alpine Linux distribution
- Small Docker image size (+/-90MB)
- Uses PHP 8.5 for the best performance, low cpu usage & memory footprint
- Can safely be updated without losing data
- Fully configurable because wp-config.php uses the environment variables you can pass as an argument to the container


## Usage

### Versioning

This image follows the **Debian versioning convention** for tagging: `<wordpress-version>-<container-revision>`

**Available tags:**

- `latest` - Latest stable release
- `<major>.<minor>.<patch>-<revision>` - Full version (e.g., `6.8.1-1`, `6.8.1-2`)
  - The first part (`6.8.1`) tracks the WordPress version included
  - The revision number (`-1`, `-2`) indicates container updates (security patches, dependency updates, configuration changes)
- `<major>.<minor>.<patch>` - Latest container revision for a WordPress version (e.g., `6.8.1` → `6.8.1-2`)
- `<major>.<minor>` - Latest patch and revision (e.g., `6.8` → `6.8.1-2`)
- `<major>` - Latest minor, patch and revision (e.g., `6` → `6.8.1-2`)

**For production use**, pin to a specific full version tag (e.g., `ghcr.io/manuroc/docker-wordpress-sqlite:7.1.3-1`) to ensure reproducible deployments and controlled updates.

### Image

Published to the GitHub Container Registry on every push to `master`:

    docker pull ghcr.io/manuroc/docker-wordpress-sqlite:latest

### Running the Container

See [docker-compose.yml](https://github.com/manuroc/docker-wordpress-sqlite/blob/master/docker-compose.yml) how to use it in your own environment.

    docker-compose up


### Optimizations & additions (compared to upstream)

- **SQLite** instead of MySQL (SQLite Database Integration plugin, WAL mode), plus `pdo_sqlite`, APCu and igbinary.
- **Persistent object cache:** atec Cache APCu drop-in, installed on new volumes (leave the plugin's own page cache off).
- **Page cache:** nginx FastCGI cache for anonymous visitors (2 min, see the `X-FastCGI-Cache` header). Logged-in users, POSTs, query strings, `wp-admin`, `wp-json` and WooCommerce cart/checkout/account are never cached.
- **Tuned nginx/PHP:** `sendfile`, open file cache, gzip 5, OPcache without timestamp checks, JIT off, smaller APCu/OPcache.
  Set `OPCACHE_VALIDATE_TIMESTAMPS=1` if you update plugins/themes from wp-admin, otherwise restart the container after updates.
- **`PHP_FPM_MAX_CHILDREN`** (default `20`): PHP worker limit, roughly 10 per 512MB RAM.
- **Hardening:** rate limiting on `wp-login.php` and `xmlrpc.php`, security headers, locally generated secret keys.
- **Reliability:** PHP-FPM and nginx restart automatically, lightweight `/fpm-ping` healthcheck, faster startup (only fixes changed permissions).

Volumes created before these changes keep their old files: install the atec Cache APCu plugin from wp-admin and enable its object cache.

### WP-CLI

This image includes [wp-cli](https://wp-cli.org/) which can be used like this:

    docker exec <your container name> /usr/local/bin/wp --path=/usr/src/wordpress <your command>

## Inspired by

- https://hub.docker.com/_/wordpress/
- https://codeable.io/wordpress-developers-intro-to-docker-part-two/
- https://github.com/TrafeX/docker-php-nginx/
- https://github.com/etopian/alpine-php-wordpress
