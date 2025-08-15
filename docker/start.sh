#!/bin/bash

# Start script for liKeYun_Ylb container
echo "Starting liKeYun_Ylb services..."

# Ensure MySQL data directory exists and has proper permissions
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MySQL database..."
    mkdir -p /var/lib/mysql
    chown -R mysql:mysql /var/lib/mysql
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
fi

# Start MySQL service first
echo "Starting MySQL..."
service mysql start

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
while ! mysqladmin ping -h"localhost" --silent; do
    sleep 1
done

# Create database and set password if not exists
echo "Setting up database..."
mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'likeyun123456';
CREATE DATABASE IF NOT EXISTS likeyun_ylb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
EOF

# Ensure upload directory exists with proper permissions
mkdir -p /var/www/html/console/upload
chown -R www-data:www-data /var/www/html/console/upload
chmod -R 777 /var/www/html/console/upload

# Ensure plugin directory has proper permissions
mkdir -p /var/www/html/console/plugin/app
chmod -R 755 /var/www/html/console/plugin/app

# Create PHP-FPM run directory
mkdir -p /var/run/php

# Start PHP-FPM
echo "Starting PHP-FPM..."
service php7.4-fpm start

# Start Nginx
echo "Starting Nginx..."
service nginx start

# Start cron service
echo "Starting cron service..."
service cron start

echo "All services started successfully!"
echo "Access the application at http://localhost/"
echo "First time setup: http://localhost/install/"

# Keep container running and show logs
tail -f /var/log/nginx/access.log /var/log/nginx/error.log