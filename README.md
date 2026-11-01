# WordPress Docker Container

Lightweight WordPress container with Nginx 1.30 & PHP-FPM 8.5 based on Alpine Linux.

Uses SQLite for database storage for speed and portability. No separate MySQL or MariaDB container necessary.

Extra PHP extensions have also been added for performance, such as APCu.

_WordPress version currently installed:_ **7.1.3**

- Can be used in production
- Optimized for 100 concurrent users
- Optimized to only use resources when there's traffic (by using PHP-FPM's ondemand PM)
- Works with Amazon Cloudfront or CloudFlare as SSL terminator and CDN
- Multi-platform, supporting AMD4, ARMv6, ARMv7, ARM64
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

**For production use**, pin to a specific full version tag (e.g., `trafex/wordpress:6.8.1-1`) to ensure reproducible deployments and controlled updates.

### Running the Container

See [docker-compose.yml](https://github.com/manuroc/docker-wordpress-sqlite/blob/master/docker-compose.yml) how to use it in your own environment.

    docker-compose up


### Performance

- **Page cache:** nginx caches pages for anonymous visitors for 2 minutes (`X-FastCGI-Cache: HIT/MISS/BYPASS` response header). Logged-in users, POST requests, URLs with a query string, `wp-admin`, `wp-login.php`, `wp-json` and WooCommerce cart/checkout/account pages are never cached. Nothing purges this cache when content changes, hence the short lifetime.
- **Object cache:** the [atec Cache APCu](https://wordpress.org/plugins/atec-cache-apcu/) object cache drop-in is installed on new volumes. Optionally activate the plugin in wp-admin for statistics and settings (leave its page cache off, nginx handles that).
- **SQLite:** the SQLite Database Integration plugin already uses WAL journaling and `synchronous=NORMAL`.
- **OPcache** does not check file timestamps, because the code is baked into the image. Set `OPCACHE_VALIDATE_TIMESTAMPS=1` if you install or update plugins/themes from wp-admin, or restart the container afterwards.
- **`PHP_FPM_MAX_CHILDREN`** (default `20`) is the maximum number of PHP workers. Size it to the container's memory (roughly 10 per 512MB).
- `wp-login.php` and `xmlrpc.php` are rate limited per client IP.

Existing volumes keep the files they were created with: to get the object cache on a volume created before this change, install the atec Cache APCu plugin from wp-admin and enable its object cache (or recreate the volume).

### WP-CLI

This image includes [wp-cli](https://wp-cli.org/) which can be used like this:

    docker exec <your container name> /usr/local/bin/wp --path=/usr/src/wordpress <your command>

## Inspired by

- https://hub.docker.com/_/wordpress/
- https://codeable.io/wordpress-developers-intro-to-docker-part-two/
- https://github.com/TrafeX/docker-php-nginx/
- https://github.com/etopian/alpine-php-wordpress
