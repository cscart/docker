# cscart-docker

This repository allows you to create an installation environment on a clean dedicated server with a public IPv4 address, obtain an SSL certificate, and automatically renew it.

Services for CS-Cart in Docker containers include Nginx, PHP-FPM with Cron, MySQL, Fail2ban, Redis, Certbot, FTP, and mail.

## Installation
Tested on Ubuntu 22.04 (LTS) x64

Required docker, docker compose plugin, curl, git, unzip DNS A record point to server IP.

Check [Official documentation](https://docs.docker.com/engine/install/ubuntu/) for docker install.
Please use strong passwords in web and FTP services!

```
apt install curl git unzip
git clone https://github.com/cscart/docker.git
cd docker
chmod +x ./install.sh
cp .env.example .env
```

Change values on **.env** file

**CSCART_ADDRESS** - your domain name (DNS A record point to server IP)

**CSCART_MYSQL_RPASS** - Mysql password for root user

**CSCART_MYSQL_PASS** - Mysql password for new user

**CERTBOT_EMAIL** - your email address for letsencrypt account registration

**CERTBOT_STAGING_MODE** (0/1) - set to 0 for valid letsencrypt SSL certificate use, 1 to staging letsencrypt SSL certificate

**CSCART_FTP_PASS** - FTP password

* View "Custom data" section in .env file for view/edit default logins, paths and etc.

run install script
```
./install.sh
```

* Download the CS-Cart installation package from our website https://www.cs-cart.com and replace to **data/www/**
```
cd data/www/
```

* Unzip the CS-Cart installation package:
```
unzip *.zip
```

* Change the owner and set file permissions for CS-Cart installation by executing these commands one by one:

```
chown -R $USER ./
chmod 644 config.local.php
chmod -R 755 design images var
find design -type f -print0 | xargs -0 chmod 644
find images -type f -print0 | xargs -0 chmod 644
find var -type f -print0 | xargs -0 chmod 644
```

Open your domain name in browser to install CS-Cart.
Use "mysql" in MySQL Server Host and credentials from .env (CSCART_MYSQL_DB, CSCART_MYSQL_USER, CSCART_MYSQL_PASS).

## Reinstall project

This command delete all containers and data.
In project directory run
```
docker compose down && rm -rf config data logs
```

## Docker commands

In root project dir you can use this commands:

docker compose stop - stop all containers

docker compose start - start all containers

docker compose down - stop and delete all containers

docker star/stop/restart *service-name* - star/stop/restart service with *service-name* (e.g. docker restart nginx)

## Customize project

### Nginx

**CSCART_NGINX_CONF** - path to custom configs

**CSCART_HOME** - web root

**CSCART_NGINX_LOGS** - path to log dir

### Mysql

The image contains default parameters; you need to customize the MySQL configuration for your server.

**CSCART_MYSQL_CONF** - path to custom config

**CSCART_MYSQL_DATA** - data dir path

**CSCART_MYSQL_LOGS** - path to log dir

Connect to Mysql database:

```
docker exec -ti mysql bash
mysql -h127.0.0.1 -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE
```

### Fail2ban

**CSCART_FAIL2BAN_DATA** - path to custom jail configs.

### Php-fpm

**CSCART_PHP_CONF** - path to custom configs.

### Cron
Create a cron job file in CSCART_CRON_DIR. For example full backup script start every day at 6.30 AM:

```
30 6 * * * root /usr/local/bin/php /var/www/html/admin.php --dispatch=datakeeper.backup --p --backup_database=Y --backup_files=Y --dbdump_tables=all --dbdump_data=Y --extra_folders[]=var/files --extra_folders[]=var/attachments --extra_folders[]=var/langs
```

### Mail

The image does not contain any DMARC, DKIM, or other security configurations.

Most likely, the mail will end up in the spam folder.

Use your custom SMTP server in the CS-Cart preferences.
