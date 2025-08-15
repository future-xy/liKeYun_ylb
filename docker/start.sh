#!/bin/bash

# Start script for liKeYun_Ylb container
echo "Starting liKeYun_Ylb services..."

# Create necessary directories
mkdir -p /var/log/mysql
mkdir -p /var/lib/mysql
mkdir -p /var/run/mysqld

# Set proper permissions
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /var/log/mysql
chown -R mysql:mysql /var/run/mysqld

# Ensure MySQL data directory exists and has proper permissions
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MySQL database..."
    # Initialize with insecure mode (no root password initially)
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql --log-error=/var/log/mysql/error.log
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
# First check if password is already set
if mysql -uroot -plikeyun123456 -e "SELECT 1;" 2>/dev/null; then
    echo "MySQL password already set"
else
    # Try without password first (fresh install)
    if mysql -uroot -e "SELECT 1;" 2>/dev/null; then
        echo "Setting MySQL root password..."
        mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'likeyun123456';
FLUSH PRIVILEGES;
EOF
    else
        echo "MySQL authentication issue, trying to reset..."
        service mysql stop
        mysqld_safe --skip-grant-tables --skip-networking &
        sleep 3
        mysql -uroot <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'likeyun123456';
FLUSH PRIVILEGES;
EOF
        killall mysqld_safe mysqld
        sleep 2
        service mysql start
        sleep 2
    fi
fi

# Create database
mysql -uroot -plikeyun123456 <<EOF
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

# Create necessary directories for services
mkdir -p /var/run/php
mkdir -p /var/log/nginx
touch /var/log/nginx/access.log
touch /var/log/nginx/error.log
chown -R www-data:www-data /var/log/nginx

# Start PHP-FPM
echo "Starting PHP-FPM..."
service php7.4-fpm start

# Start Nginx
echo "Starting Nginx..."
service nginx start

# Check if Nginx started successfully
if ! pgrep nginx > /dev/null; then
    echo "Nginx failed to start, checking configuration..."
    nginx -t
    echo "Attempting to start nginx directly..."
    nginx -g "daemon off;" &
    sleep 2
fi

# Start cron service
echo "Starting cron service..."
service cron start

echo "All services started successfully!"
echo "Access the application at http://localhost/"
echo "First time setup: http://localhost/install/"

# Health check function
check_services() {
    while true; do
        # Check if MySQL is running
        if ! pgrep mysql > /dev/null; then
            echo "MySQL stopped, restarting..."
            service mysql start
        fi
        
        # Check if Nginx is running
        if ! pgrep nginx > /dev/null; then
            echo "Nginx stopped, restarting..."
            service nginx start
        fi
        
        # Check if PHP-FPM is running
        if ! pgrep php-fpm > /dev/null; then
            echo "PHP-FPM stopped, restarting..."
            service php7.4-fpm start
        fi
        
        sleep 30
    done
}

# Start health check in background
check_services &

# Keep container running and show logs
tail -f /var/log/nginx/access.log /var/log/nginx/error.log 2>/dev/null || tail -f /dev/null