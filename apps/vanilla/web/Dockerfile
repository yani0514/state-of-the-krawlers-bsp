#FROM php:7.1.33-apache
FROM php:5.6-apache
# xdebug 2.5.5 needs PHP < 7.2.0

# Debian Stretch is archived.
RUN printf '%s\n' \
    'deb [trusted=yes] http://archive.debian.org/debian stretch main' \
    'deb [trusted=yes] http://archive.debian.org/debian-security stretch/updates main' \
    > /etc/apt/sources.list \
    && printf '%s\n' \
       'Acquire::Check-Valid-Until "false";' \
       'Acquire::AllowInsecureRepositories "true";' \
       > /etc/apt/apt.conf.d/99archive \
    && apt-get update \
    && apt-get install -y --no-install-recommends git \
    && pecl install xdebug-2.5.5 \
    && docker-php-ext-enable xdebug \
    && docker-php-ext-install mysqli pdo_mysql \
    && rm -rf /var/lib/apt/lists/* \
    && echo 'ServerName web' >> /etc/apache2/apache2.conf \
    && echo 'auto_prepend_file = "/var/www/html/xdebug.php"' \
       >> "$PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini"

COPY src/ /var/www/html

RUN chmod -R 777 \
    /var/www/html/conf \
    /var/www/html/cache \
    /var/www/html/uploads

COPY config.php /var/www/html/conf/config.php
COPY xdebug.php /var/www/html/xdebug.php

ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
