#!/bin/bash
service mysql stop
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld
echo 'slow-query-log-file=/zbp-app-validator/tmp/mysql-slow.log' >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo 'opcache.enable=0' >> /etc/php/8.0/fpm/php.ini
service mysql start

echo '127.0.0.1 zblogphp.local' >> /etc/hosts
mysql -u root --password=rootpassword --execute="create database userdb;"
mysql -u root --password=rootpassword --execute="CREATE USER 'user'@'localhost' IDENTIFIED BY 'userpassword';"
mysql -u root --password=rootpassword --execute="grant all privileges on userdb.* to user@localhost ;"
mysql -u user --password=userpassword --default-character-set=utf8mb4 -Duserdb < /zbp-app-validator/docker-scripts/data/data.sql
service mysql stop

bash -c "echo \"gzip on;
gzip_disable \\\"msie6\\\";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_min_length 256;
gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/vnd.ms-fontobject application/x-font-ttf font/opentype image/svg+xml image/x-icon;
\" > /etc/nginx/gzip.conf"

cp /zbp-app-validator/docker-scripts/data/config.json /zbp-app-validator/config.json
cp /zbp-app-validator/docker-scripts/data/c_option.php /zbp-app-validator/resources/zb_users/c_option.php
