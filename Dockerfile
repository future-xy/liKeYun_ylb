FROM ubuntu:20.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# Install system dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    php7.4 \
    php7.4-fpm \
    php7.4-mysql \
    php7.4-json \
    php7.4-curl \
    php7.4-gd \
    php7.4-mbstring \
    php7.4-xml \
    php7.4-zip \
    php7.4-intl \
    php7.4-bcmath \
    mysql-server \
    supervisor \
    cron \
    curl \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Configure PHP-FPM
RUN sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.4/fpm/php.ini \
    && sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 50M/' /etc/php/7.4/fpm/php.ini \
    && sed -i 's/post_max_size = 8M/post_max_size = 50M/' /etc/php/7.4/fpm/php.ini \
    && sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/7.4/fpm/php.ini \
    && sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/7.4/fpm/php.ini

# Configure Nginx
COPY docker/nginx.conf /etc/nginx/sites-available/default

# MySQL will be configured at runtime via start.sh
# We just need to ensure the MySQL user exists
RUN usermod -d /var/lib/mysql/ mysql

# Create application directory
WORKDIR /var/www/html

# Copy application files
COPY . /var/www/html/

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/console/upload \
    && chmod -R 755 /var/www/html/console/plugin/app

# Create database configuration file
RUN mkdir -p /var/www/html/console \
    && echo '<?php' > /var/www/html/console/Db.php \
    && echo '' >> /var/www/html/console/Db.php \
    && echo '$config = array(' >> /var/www/html/console/Db.php \
    && echo "    'db_host' => 'localhost'," >> /var/www/html/console/Db.php \
    && echo "    'db_port' => 3306," >> /var/www/html/console/Db.php \
    && echo "    'db_name' => 'likeyun_ylb'," >> /var/www/html/console/Db.php \
    && echo "    'db_user' => 'root'," >> /var/www/html/console/Db.php \
    && echo "    'db_pass' => 'likeyun123456'," >> /var/www/html/console/Db.php \
    && echo "    'db_prefix' => ''," >> /var/www/html/console/Db.php \
    && echo "    'folderNum' => 'common'," >> /var/www/html/console/Db.php \
    && echo "    'version' => '2.4.6'" >> /var/www/html/console/Db.php \
    && echo ');' >> /var/www/html/console/Db.php \
    && echo '' >> /var/www/html/console/Db.php \
    && echo '?>' >> /var/www/html/console/Db.php

# Configure Supervisor
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create startup script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start services
CMD ["/start.sh"] 