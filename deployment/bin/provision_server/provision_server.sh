#!/bin/bash

set -ex

MYSQL_PASSWORD=$1
SSH_KEY=$2

PROJECT_DIR="/var/www/html/posts"

mkdir -p $PROJECT_DIR

chown -R www-data:www-data $PROJECT_DIR

cd $PROJECT_DIR

git config --global --add safe.directory $PROJECT_DIR

if [ ! -d $PROJECT_DIR"/.git" ]; then
  GIT_SSH_COMMAND='ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes' git clone git@github.com:laerciokelson/devops.git .
  cp $PROJECT_DIR"/api/.env.example" $PROJECT_DIR"/api/.env"
  sed -i "/DB_PASSWORD/c\DB_PASSWORD=$MYSQL_PASSWORD" $PROJECT_DIR"/api/.env"
  sed -i '/QUEUE_CONNECTION/c\QUEUE_CONNECTION=database' $PROJECT_DIR"/api/.env"
fi

# node & npm
rm -f /usr/bin/node
rm -f /usr/bin/npm
rm -f /usr/bin/npx

cd /usr/lib
wget https://nodejs.org/dist/v14.21.3/node-v14.21.3-linux-x64.tar.xz
tar xf node-v14.21.3-linux-x64.tar.xz
rm node-v14.21.3-linux-x64.tar.xz
mv ./node-v14.21.3-linux-x64/bin/node /usr/bin/node
ln -s /usr/lib/node-v14.21.3-linux-x64/lib/node_modules/npm/bin/npm-cli.js /usr/bin/npm
ln -s /usr/lib/node-v14.21.3-linux-x64/lib/node_modules/npx/bin/npx-cli.js /usr/bin/npx

# php 8.1
add-apt-repository ppa:ondrej/php -y
apt update -y
apt install php8.1-common php8.1-cli -y
apt install php8.1-dom -y
apt install php8.1-gd -y
apt install php8.1-zip -y
apt install php8.1-curl -y
apt install php8.1-mysql -y
apt install php8.1-sqlite3 -y
apt install php8.1-mbstring -y
apt install php8.1-fpm -y

apt install net-tools -y
apt install supervisor -y
apt install unzip

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/bin/composer

mysql -uroot -p$MYSQL_PASSWORD < $PROJECT_DIR"/deployment/config/mysql/create_database.sql" || echo "Database already exists"
mysql -uroot -p$MYSQL_PASSWORD < $PROJECT_DIR"/deployment/config/mysql/set_native_password.sql"

echo "* * * * * cd $PROJECT_DIR && php artisan schedule:run >> /dev/null 2>&1" >> cron_tmp
crontab cron_tmp
rm cron_tmp

cp $PROJECT_DIR"/deployment/config/supervisor/logrotate" /etc/logrotate.d/supervisor

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

aws configure

useradd -G www-data,root -u 1000 -d /home/laercio laercio
mkdir -p /home/laercio/.ssh
touch /home/laercio/.ssh/authorized_keys
chown -R laercio:laercio /home/laercio
chown -R laercio:laercio /var/www/html
chmod 700 /home/laercio/.ssh
chmod 644 /home/laercio/.ssh/authorized_keys

echo "$SSH_KEY" >> /home/laercio/.ssh/authorized_keys

echo "laercio ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/laercio

php -v
node -v
npm -v
aws --version
