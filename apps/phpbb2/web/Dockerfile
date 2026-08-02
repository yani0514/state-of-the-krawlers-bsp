#FROM php:5.3-apache
FROM php:5.6-apache
# xdebug needs PHP < 7.2.0

ENV PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d

# Debian Stretch is archived. Use the archive repositories and disable
# expiry/signature checks that no longer work for this historical image.
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
    && docker-php-ext-install mysql mysqli pdo pdo_mysql \
    && rm -rf /var/lib/apt/lists/* \
    && echo 'ServerName web' >> /etc/apache2/apache2.conf \
    && mkdir -p "$PHP_INI_SCAN_DIR" \
    && echo 'zend_extension="/usr/local/lib/php/extensions/no-debug-non-zts-20131226/xdebug.so"' \
       >> "$PHP_INI_SCAN_DIR/docker-php-ext-xdebug.ini" \
    && echo 'auto_prepend_file = "/var/www/html/xdebug.php"' \
       >> "$PHP_INI_SCAN_DIR/docker-php-ext-xdebug.ini"

RUN git clone https://github.com/phpbb/phpbb.git \
    -b release-2.0.23 \
    /tmp/phpbb \
    && mv /tmp/phpbb/phpBB/* /var/www/html/

RUN rm -rf /var/www/html/install /var/www/html/contrib

COPY xdebug.php config.php /var/www/html/

ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
