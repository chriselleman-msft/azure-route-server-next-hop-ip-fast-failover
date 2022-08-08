#!/usr/bin/env bash

OLD_PWD=`pwd`

echo "Update packages"
apt-get update && apt-get upgrade -y

echo "Install packages"
apt-get install -y apache2 libapache2-mod-php

echo "Rename web index to php"
mv /var/www/html/index.html /var/www/html/index.php

echo "Overwrite index to php file"
cat << EOF > /var/www/html/index.php
<?php
header('Content-type: application/json');
\$output = array(
    hostname  => gethostname(),
    ip => getHostByName(getHostName()),
    timestampmilli => intval(microtime(true)*1000)
);
echo json_encode(\$output);
?>
EOF

echo "Install yq"
# don't use snap as its a nightmare, use the binary release from github
# snap install yq
cd /tmp
wget "https://github.com/mikefarah/yq/releases/download/v4.27.2/yq_linux_amd64"
mv yq_linux_amd64 /tmp/yq
chmod +x /tmp/yq
mv /tmp/yq /usr/bin

echo "Update netplan config to include VIP"
cp /etc/netplan/50-cloud-init.yaml /tmp/50-cloud-init.yaml
cp /etc/netplan/50-cloud-init.yaml /tmp/50-cloud-init.yaml.orig
yq -i '.network.ethernets.eth0 += {"addresses" : ["10.10.15.15/32"]}' /tmp/50-cloud-init.yaml
cp /tmp/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml
netplan apply
apachectl restart

cd $OLD_PWD