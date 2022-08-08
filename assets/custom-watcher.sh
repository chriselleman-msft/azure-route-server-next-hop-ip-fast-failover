#!/usr/bin/env bash

OLD_PWD=`pwd`

echo "Update packages"
apt-get update && apt-get upgrade -y

echo "Install packages"
apt-get install -y apache2 libapache2-mod-php rsyslog bird2

echo "Rename web index to php"
mv /var/www/html/index.html /var/www/html/index.php

echo "Overwrite index to php file"
cat << EOF > /var/www/html/index.php
Watcher VM
EOF

cd $OLD_PWD