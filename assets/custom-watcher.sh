#!/usr/bin/env bash

OLD_PWD=`pwd`

echo "Update packages"
apt-get update && apt-get upgrade -y

echo "Install packages"
apt-get install -y apache2 libapache2-mod-php rsyslog exabgp socat

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
# Update service to run as exabgp - fix for ubuntu20.04LTS
sed '/#User=/s/^#//' -i /lib/systemd/system/exabgp.service
sed '/#Group=/s/^#//' -i /lib/systemd/system/exabgp.service
systemctl daemon-reload
systemctl restart exabgp


echo "Build Monitoring Script"
cat << EOF | tee -a /root/monitoring_script.sh
#!/usr/bin/env bash

PRIMARY_ENDPOINT=10.10.0.4
SECONDARY_ENDPOINT=10.10.0.5
VIP_ROUTE="100.64.0.1/32"
TARGET_ENDPOINT=\$PRIMARY_ENDPOINT
LIVE_ENDPOINT=pri
TEST_COMMAND="curl --max-time 0.1 -q http://\\\${TARGET_ENDPOINT}/ 2>&1 >/dev/null"

# test running as root
if ! [ $(id -u) = 0 ]; then
   sudo \$0 \$@
   exit
fi

exec 1> >(logger -s -t \$(basename \$0)) 2>&1

echo "Script start"
while true; do
        # test secondary first
        TARGET_ENDPOINT=\$SECONDARY_ENDPOINT
        COMMAND_RESULT=\`eval \\\${TEST_COMMAND}\`
        SEC_RESULT=\$?
        # test primary endpoint
        TARGET_ENDPOINT=\$PRIMARY_ENDPOINT
        COMMAND_RESULT=\`eval \\\${TEST_COMMAND}\`
        PRI_RESULT=\$?
        # make decision
        if [ \$LIVE_ENDPOINT == "pri" ] && [ \$PRI_RESULT -eq 0 ] ; then
                sleep 0.1
        elif [ \$LIVE_ENDPOINT == "pri" ] && [ \$PRI_RESULT -ne 0 ] && [ \$SEC_RESULT -eq 0 ]; then
                # issue failover primary to secondary
                STAMP=\`date +%s.%3N\`
                echo "\$STAMP: failing from primary to secondary"
                echo "announce route \$VIP_ROUTE next-hop \$SECONDARY_ENDPOINT" >/etc/exabgp/exabgp.cmd;
                LIVE_ENDPOINT=sec
        elif [ \$PRI_RESULT -ne 0 ] && [ \$SEC_RESULT -ne 0 ]; then
                STAMP=\`date +%s.%3N\`
                echo "\$STAMP: both endpoints down, doing nothing"
                sleep 0.1
        elif [ \$LIVE_ENDPOINT == "sec" ] && [ \$PRI_RESULT -ne 0 ] && [ \$SEC_RESULT -eq 0 ]; then
                # echo primary still failed
                sleep 0.1
        elif [ \$LIVE_ENDPOINT == "sec" ] && [ \$PRI_RESULT -eq 0 ]; then
                # fail back
                STAMP=\`date +%s.%3N\`
                echo "\$STAMP: failing from secondary to primary"
                echo "announce route \$VIP_ROUTE next-hop \$PRIMARY_ENDPOINT" >/etc/exabgp/exabgp.cmd;
                LIVE_ENDPOINT=pri
        else
                STAMP=\`date +%s.%3N\`
                echo "\$STAMP: Error, should not be here, debug information below"
                set
                exit
        fi
done
EOF
chmod +x /root/monitoring_script.sh

cat << EOF | tee -a /lib/systemd/system/monitoring_script.service
[Unit]
Description=monitoring_script
Documentation=https://github.com/chriselleman-msft/azure-route-server-next-hop-ip-fast-failover
After=exabgp.service

[Service]
User=root
Group=root
ExecStart=/bin/bash -c "/root/monitoring_script.sh"

[Install]
WantedBy=multi-user.target
EOF
systemctl enable monitoring_script.service
systemctl start monitoring_script.service



cd $OLD_PWD