FROM php:7.1.33-apache

# Debian Buster is archived, so use the Debian archive repositories.
RUN printf '%s\n' \
    'deb http://archive.debian.org/debian buster main' \
    'deb http://archive.debian.org/debian-security buster/updates main' \
    > /etc/apt/sources.list \
    && printf 'Acquire::Check-Valid-Until "false";\n' \
    > /etc/apt/apt.conf.d/99no-check-valid-until

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl \
    && pecl install xdebug-2.5.5 \
    && docker-php-ext-enable xdebug \
    && docker-php-ext-install mysqli \
    && rm -rf /var/lib/apt/lists/* \
    && echo 'ServerName web' >> /etc/apache2/apache2.conf \
    && echo 'auto_prepend_file = "/var/www/html/xdebug.php"' \
       >> "$PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini"

RUN git clone --branch v2.102 --depth 1 \
    https://github.com/kohler/hotcrp.git /var/www/html

COPY xdebug.php /var/www/html/xdebug.php
COPY options.php /var/www/html/conf/options.php

ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]