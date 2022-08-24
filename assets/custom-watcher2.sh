#!/usr/bin/env bash

OLD_PWD=`pwd`

echo "Update packages"
apt-get update && apt-get upgrade -y

echo "Install packages"
apt-get install -y quagga

echo "Quagga Config"
cat << EOF | tee -a /etc/quagga/bgpd.conf
!
log file /var/log/quagga/quagga.log
!
router bgp 65002
 bgp router-id 10.10.0.8
 neighbor 10.10.0.7 remote-as 65001
 neighbor 10.10.0.7 description "watch1"
!
 address-family ipv6
 exit-address-family
 exit
!
line vty
!
EOF

cat << EOF | tee -a /etc/quagga/zebra.conf
!
log file /var/log/quagga/quagga.log
!
interface eth0
!
interface lo
!
router-id 10.10.0.8
!
!
line vty
!
EOF
chown quagga /etc/quagga/*
mkdir /var/log/quagga
chown quagga /var/log/quagga

echo "add user to group, so can run vtysh"
adduser chris quaggavty

systemctl enable zebra
systemctl enable bgpd
systemctl restart zebra
systemctl restart bgpd

cd $OLD_PWD