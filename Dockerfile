FROM ubuntu:18.04
MAINTAINER zsx<zsx@zsxsoft.com>
ENV NODEJS_VERSION v10.15.0
ENV DEBIAN_FRONTEND=noninteractive

ARG location
RUN export NODEJS_HOST=https://nodejs.org/dist/; if [ "x$location" = "xchina" ]; then echo "Changed Ubuntu source"; cp /etc/apt/sources.list /etc/apt/sources.list.bak; touch /etc/apt/sources.list; echo 'deb http://mirrors.tencent.com/debian buster main contrib non-free' >> /etc/apt/sources.list; echo 'deb http://mirrors.tencent.com/debian buster-updates main contrib non-free' >> /etc/apt/sources.list; echo 'deb http://mirrors.tencent.com/debian-security buster/updates main' >> /etc/apt/sources.list; echo 'deb-src http://mirrors.tencent.com/debian buster main contrib non-free' >> /etc/apt/sources.list; echo 'deb-src http://mirrors.tencent.com/debian buster-updates main contrib non-free' >> /etc/apt/sources.list; echo 'deb-src http://mirrors.tencent.com/debian-security buster/updates main' >> /etc/apt/sources.list; export NPM_CONFIG_REGISTRY=https://registry.npm.taobao.org; export ELECTRON_MIRROR=http://npm.taobao.org/mirrors/electron/; export PUPPETEER_DOWNLOAD_HOST=https://npm.taobao.org/mirrors; export NODEJS_HOST=https://npm.taobao.org/mirrors/node/; fi; \
    \
    mkdir /data/ /data/logs/ /data/logs/nginx /data/www/ /data/tools /www/ \
    && mkdir /zbp-app-validator \
    && apt-get update \
    && apt-get -y install software-properties-common \
# Base
    && apt-get -y install git curl wget iptables unzip sudo \
    && (echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list) \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
# Fonts (Chinese)
    && apt-get install -y --no-install-recommends fonts-noto fonts-noto-cjk fonts-noto-color-emoji \
# nginx & PHP
    && LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php \
    && if [ "x$location" = "xchina" ]; then echo "Changed Ubuntu source"; find /etc/apt/sources.list.d/ -type f -name "*.list" -exec  sed  -i.bak -r  's#deb(-src)?\s*http(s)?://ppa.launchpad.net#deb\1 https://launchpad.proxy.ustclug.org#ig' {} \; ;fi \
    && apt-get update \
    && apt-get -y install nginx php8.0-fpm php8.0-gd php8.0-curl php8.0-mysql php8.0-cli php8.0-xml php8.0-json php8.0-mbstring php8.0-cli php8.0-dev php8.0-sqlite3 php8.0-zip php-pear \
    && pecl install uopz \
    && rm -rf /etc/nginx/sites-enabled/default \
    && curl https://getcomposer.org/installer | php -- --filename=composer \
    && chmod a+x composer \
    && mv composer /usr/local/bin/composer \
    && (echo extension=uopz.so > /etc/php/8.0/mods-available/uopz.ini) \
    && (echo extension=uopz.so > /etc/php/8.0/fpm/conf.d/uopz.ini) \
    && (echo extension=uopz.so > /etc/php/8.0/cli/conf.d/uopz.ini) \
    && rm -rf /tmp/pear \
# Nodejs
    && apt-get -y install yarn \
    && wget "$NODEJS_HOST/$NODEJS_VERSION/node-$NODEJS_VERSION-linux-x64.tar.xz" -O/tmp/node.tar.xz \
    && tar -C /usr/local/ -xvf /tmp/node.tar.xz --strip-components 1 \
# Java
    && apt-get -y install openjdk-8-jre \
# Chromium
    && apt-get -y install libgtk-3-0 libnss3 libnss3-tools libasound2 libxss1 \
# MySQL
    && bash -c "debconf-set-selections <<< 'mysql-server mysql-server/root_password password rootpassword'" \
    && bash -c "debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password rootpassword'" \
    && apt-get -y install mysql-server \
    && mkdir /var/run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
# Clean rubbish
    && apt-get -y remove php8.0-dev php-pear \
    && apt-get -y autoremove \
    && apt-get autoclean \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*

COPY env/* /tmp/
# mitmproxy
RUN if [ ! -f /tmp/mitmproxy.tar.gz ]; then wget https://github.com/mitmproxy/mitmproxy/releases/download/v4.0.1/mitmproxy-4.0.1-linux.tar.gz -O/tmp/mitmproxy.tar.gz; fi\
    && tar -C /usr/local/bin -xvf /tmp/mitmproxy.tar.gz \
    && chmod 0777 /usr/local/bin/mitmdump /usr/local/bin/mitmproxy /usr/local/bin/mitmweb \
    && sysctl -w net.ipv4.ip_forward=1

RUN mkdir /data/certs \
    && ln -s /data/certs /root/.mitmproxy \
    && timeout 5s mitmdump || true \
    && cp /root/.mitmproxy/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy.crt \
    && update-ca-certificates --fresh

COPY ./docker-scripts/64-language-selector-prefer.conf /etc/fonts/conf.d/64-language-selector-prefer.conf
RUN fc-cache -fv

COPY package.json composer.json composer.lock /zbp-app-validator/
WORKDIR /zbp-app-validator/

RUN if [ "x$location" = "xchina" ]; then composer config -g repo.packagist composer https://mirrors.tencent.com/composer/; export NPM_CONFIG_REGISTRY=https://registry.npm.taobao.org; export ELECTRON_MIRROR=http://npm.taobao.org/mirrors/electron/; export PUPPETEER_DOWNLOAD_HOST=https://npm.taobao.org/mirrors; export SASS_BINARY_SITE=http://npm.taobao.org/mirrors/node-sass; fi; \
    yarn && yarn cache clean --force && composer install && composer clearcache

COPY ./ /zbp-app-validator/
RUN chmod 0777 /zbp-app-validator/docker-scripts/* \
    && bash /zbp-app-validator/docker-scripts/docker-init.sh \
    && bash /zbp-app-validator/docker-scripts/create-site.sh local zblogphp.local

ENV HOME=/data/www/local/home

ENTRYPOINT ["/zbp-app-validator/docker-scripts/run.sh"]
