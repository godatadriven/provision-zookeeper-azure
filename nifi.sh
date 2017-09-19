#!/bin/bash

NIFI_HOME=/opt
NIFI_VERSION=1.3.0

# install Java 8
cd /tmp
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u144-b01/090f390dda5b47b9b721c7dfaa008135/jdk-8u144-linux-x64.rpm"
yum -y localinstall jdk-8u144-linux-x64.rpm

# Install NiFi
cd $NIFI_HOME
wget http://www-eu.apache.org/dist/nifi/$NIFI_VERSION/nifi-$NIFI_VERSION-bin.tar.gz
tar -xvzf nifi-$NIFI_VERSION-bin.tar.gz

cd $NIFI_HOME/nifi-$NIFI_VERSION

# set config files

# nifi.properties
cd conf

sed -i "s/^nifi.web.http.host=/nifi.web.http.host=10.0.2.$(($1+1))/g" $NIFI_HOME/nifi-$NIFI_VERSION/conf/nifi.properties
sed -i "s/^nifi.web.http.port=8080/nifi.web.http.port=7070/g" $NIFI_HOME/nifi-$NIFI_VERSION/conf/nifi.properties
sed -i "s/^nifi.zookeeper.connect.string=/nifi.zookeeper.connect.string=10.0.1.1:2181,10.0.1.2:2181,10.0.1.3:2181/g" $NIFI_HOME/nifi-$NIFI_VERSION/conf/nifi.properties
sed -i "s/^nifi.cluster.is.node=/nifi.cluster.is.node=true/g" $NIFI_HOME/nifi-$NIFI_VERSION/conf/nifi.properties
sed -i "s/^nifi.cluster.node.address=/nifi.cluster.node.address=10.0.2.$(($1+1))/g" $NIFI_HOME/nifi-$NIFI_VERSION/conf/nifi.properties
sed -i "s/^nifi.cluster.node.protocol.port=/nifi.cluster.node.protocol.port=12000/g" $NIFI_HOME/nifi-$NIFI_VERSION/conf/nifi.properties


$NIFI_HOME/$NIFI_VERSION/bin/nifi.sh start
