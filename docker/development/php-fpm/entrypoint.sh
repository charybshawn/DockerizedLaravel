#!/bin/bash
set -e

# Set proper permissions for storage and bootstrap/cache
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache 2>/dev/null || true
chmod -R 775 /var/www/storage /var/www/bootstrap/cache 2>/dev/null || true

# Generate application key if not set (for development)
if [ -z "$APP_KEY" ] && [ -f "/var/www/.env" ]; then
    echo "Generating application key..."
    php artisan key:generate --no-interaction --force
fi

# Clear config cache in development
php artisan config:clear 2>/dev/null || true

echo "Starting PHP-FPM for development..."
exec "$@"