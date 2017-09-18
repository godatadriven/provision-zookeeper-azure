#!/bin/bash
cd /tmp
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u144-b01/090f390dda5b47b9b721c7dfaa008135/jdk-8u144-linux-x64.rpm"
yum -y localinstall jdk-8u144-linux-x64.rpm

cd /opt
wget http://www-eu.apache.org/dist/nifi/1.3.0/nifi-1.3.0-bin.tar.gz
tar -xzf nifi-1.3.0-bin.tar.gz
cd nifi-1.3.0
