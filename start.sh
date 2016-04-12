#!/bin/sh

# Run setup whenever container is starting
/scripts/setup.sh || {
  echo "Setup error"
  exit 1
}

DOMAINS="localhost $DOMAIN"
RULES=""

if [ "$REDIRECT_TO_WWW_DOMAIN" != "0" ]; then
    DOMAINS="$DOMAINS www.$DOMAIN"

    RULES="
        if (\$host != 'www.$DOMAIN') {
            rewrite   ^  http://www.$DOMAIN\$request_uri?;
        }
"
fi

# Configure nginx
mkdir -p /etc/nginx/conf

cat <<EOF > /etc/nginx/nginx.conf
daemon            off;
worker_processes  1;

error_log         /dev/stdout info;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    keepalive_timeout  15;
    autoindex          off;
    server_tokens      off;
    port_in_redirect   off;
    sendfile           on;
    tcp_nopush         on;
    tcp_nodelay        on;

    client_max_body_size 64m;
    client_header_buffer_size 16k;
    large_client_header_buffers 4 16k;

    ## Cache open FD
    open_file_cache max=10000 inactive=3600s;
    open_file_cache_valid 7200s;
    open_file_cache_min_uses 2;

    ## Gzipping is an easy way to reduce page weight
    gzip                on;
    gzip_vary           on;
    gzip_proxied        any;
    gzip_types          application/javascript application/x-javascript application/rss+xml text/javascript text/css image/svg+xml;
    gzip_buffers        16 8k;
    gzip_comp_level     6;

    access_log         /dev/stdout;

    server {
        listen $NGINX_PORT;
        server_name $DOMAINS;
        set \$MAGE_ROOT $MAGENTO_ROOT;
        set \$MAGE_MODE production;
        include /etc/nginx/conf/magento.conf;
    }
}
EOF

cat <<EOF > /etc/nginx/conf/magento.conf
root \$MAGE_ROOT/pub;

index index.php;
autoindex off;
charset off;

location /setup {
    root \$MAGE_ROOT;

    location ~ ^/setup/index.php {
        include /etc/nginx/conf/fastcgi_params.conf;
    }
}

location / {
    try_files \$uri \$uri/ /index.php?\$args;
}

location /pub {
    alias \$MAGE_ROOT/pub;
}

location /static/ {
    if (\$MAGE_MODE = "production") {
        expires max;
    }
    location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)$ {
        add_header Cache-Control "public";
        expires +1y;

        if (!-f \$request_filename) {
            rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
        }
    }
    location ~* \.(zip|gz|gzip|bz2|csv|xml)$ {
        add_header Cache-Control "no-store";
        expires    off;

        if (!-f \$request_filename) {
           rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
        }
    }
    if (!-f \$request_filename) {
        rewrite ^/static/(version\d*/)?(.*)$ /static.php?resource=\$2 last;
    }
}

location /media/ {
    try_files \$uri \$uri/ /get.php?\$args;
    location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)$ {
        add_header Cache-Control "public";
        expires +1y;
        try_files \$uri \$uri/ /get.php?\$args;
    }
    location ~* \.(zip|gz|gzip|bz2|csv|xml)$ {
        add_header Cache-Control "no-store";
        expires    off;
        try_files \$uri \$uri/ /get.php?\$args;
    }
}

location /media/customer/ {
    deny all;
}

location /media/downloadable/ {
    deny all;
}

location ~ /media/theme_customization/.*\.xml$ {
    deny all;
}

location /errors/ {
    try_files \$uri =404;
}

location ~ ^/errors/.*\.(xml|phtml)$ {
    deny all;
}

location ~ cron\.php {
    deny all;
}

location ~ (index|get|static|report|404|503)\.php$ {
    try_files \$uri =404;
    fastcgi_param  PHP_FLAG  "session.auto_start=off \n suhosin.session.cryptua=off";
    fastcgi_param  PHP_VALUE "memory_limit=1024M \n max_execution_time=600";
    fastcgi_read_timeout 600s;
    fastcgi_connect_timeout 600s;
    fastcgi_param  MAGE_MODE \$MAGE_MODE;
    include /etc/nginx/conf/fastcgi_params.conf;
}
EOF

cat <<EOF > /etc/nginx/conf/fastcgi_params.conf
fastcgi_pass            127.0.0.1:9000;
fastcgi_split_path_info ^(.+\.php)(/.+)$;
fastcgi_index index.php;

# Required if PHP was built with --enable-force-cgi-redirect.
fastcgi_param REDIRECT_STATUS 200;

# Variables to make the $_SERVER populate in PHP.
fastcgi_param CONTENT_TYPE \$content_type;
fastcgi_param CONTENT_LENGTH \$content_length;
fastcgi_param DOCUMENT_URI \$document_uri;
fastcgi_param DOCUMENT_ROOT \$document_root;
fastcgi_param GATEWAY_INTERFACE CGI/1.1;
fastcgi_param HTTPS \$https if_not_empty;
fastcgi_param QUERY_STRING \$query_string;
fastcgi_param REMOTE_ADDR \$remote_addr;
fastcgi_param REMOTE_PORT \$remote_port;
fastcgi_param REQUEST_METHOD \$request_method;
fastcgi_param REQUEST_URI \$request_uri;
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
fastcgi_param SERVER_ADDR \$server_addr;
fastcgi_param SERVER_PORT \$server_port;
fastcgi_param SERVER_NAME \$server_name;
fastcgi_param SERVER_PROTOCOL \$server_protocol;
fastcgi_param SERVER_SOFTWARE nginx/\$nginx_version;
EOF

# Configure supervisord
mkdir -p /etc/supervisor.d/
cat <<EOF > /etc/supervisor.d/supervisord.ini
[program:php-fpm]
command=php-fpm --nodaemonize
autostart=true
autorestart=true

umask=002
priority=1
startretries=3
stopwaitsecs=10

stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=nginx
autostart=true
autorestart=true

umask=002
priority=2
startretries=3
stopwaitsecs=10

stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:mysqld]
command=mysqld_safe
autostart=true
autorestart=true

numprocs=$( [ "$MYSQL_HOST" == "localhost" ] && echo "1" || echo "0" )

[program:cron]
command=crond -f -L -
autostart=true
autorestart=true

stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Configure crontab
PHP_BIN=$(which php)
cat <<EOF | crontab -
*/1 * * * * $PHP_BIN -c $PHP_INI $MAGENTO_ROOT/bin/magento cron:run > /dev/null
*/1 * * * * $PHP_BIN -c $PHP_INI $MAGENTO_ROOT/bin/magento setup:cron:run > /dev/null
EOF

exec supervisord -c /etc/supervisord.conf -n
