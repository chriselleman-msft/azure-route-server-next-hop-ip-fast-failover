#!/usr/bin/env bash

OLD_PWD=`pwd`

echo "Update packages"
apt-get update && apt-get upgrade -y

echo "Install packages"
apt-get install -y apache2 libapache2-mod-php rsyslog exabgp socat python3-pip
pip3 install exabgpctl

echo "Rename web index to php"
mv /var/www/html/index.html /var/www/html/index.php

echo "Overwrite index to php file"
cat << EOF > /var/www/html/index.php
Watcher VM
EOF

echo "ExaBGP Config"
mkfifo /etc/exabgp/exabgp.cmd
cat << EOF | tee -a /etc/exabgp/exabgp.conf
# Control Pipe
process route-announce {
    run /usr/bin/socat stdout pipe:/etc/exabgp/exabgp.cmd;
    encoder json;
}

neighbor 10.10.1.4 {
        router-id 10.10.0.7;
        local-address 10.10.0.7;
        local-as 65001;
        peer-as 65515;
        capability {
                graceful-restart 10;
        }
        api send1 {
                processes [route-announce];
        }
        static {
            route 100.64.0.1/32 next-hop 10.10.0.4;
        }
}

neighbor 10.10.1.5 {
        router-id 10.10.0.7;
        local-address 10.10.0.7;
        local-as 65001;
        peer-as 65515;
        capability {
                graceful-restart 10;
        }
        api send2 {
                processes [route-announce];
        }
        static {
            route 100.64.0.1/32 next-hop 10.10.0.4;
        }
}

neighbor 10.10.0.8 {
        router-id 10.10.0.7;
        local-address 10.10.0.7;
        local-as 65001;
        peer-as 65002;
        capability {
                graceful-restart 10;
        }
        api send {
                processes [route-announce];
        }
        static {
            route 100.64.0.1/32 next-hop 10.10.0.4;
        }
}
EOF
chown exabgp /etc/exabgp/*
systemctl enable exabgp
systemctl restart exabgp

cd $OLD_PWD