FROM bitnamilegacy/joomla-archived:3.9.6

COPY docker-php-ext-enable /usr/bin/

ENV PHP_INI_DIR=/opt/bitnami/php/etc

RUN printf '%s\n' \
    'deb [trusted=yes] http://archive.debian.org/debian stretch main' \
    'deb [trusted=yes] http://archive.debian.org/debian-security stretch/updates main' \
    > /etc/apt/sources.list \
    && printf '%s\n' \
       'Acquire::Check-Valid-Until "false";' \
       'Acquire::AllowInsecureRepositories "true";' \
       > /etc/apt/apt.conf.d/99archive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       autoconf \
       build-essential \
    && pecl install xdebug-2.5.5 \
    && mkdir -p "$PHP_INI_DIR/conf.d" \
    && printf 'zend_extension=%s/xdebug.so\n' "$(php-config --extension-dir)" \
       > "$PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini" \
    && printf '%s\n' 'auto_prepend_file = "/opt/xdebug.php"' \
       >> "$PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini" \
    && rm -rf /var/lib/apt/lists/*

COPY xdebug.php /opt/xdebug.php
