#!/bin/bash
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u144-b01/090f390dda5b47b9b721c7dfaa008135/jdk-8u144-linux-x64.rpm"
yum localinstall jdk-8u144-linux-x64.rpm

cd /usr/local

wget "http://apache.mirror.triple-it.nl/zookeeper/zookeeper-3.4.9/zookeeper-3.4.9.tar.gz"
tar -xvf "zookeeper-3.4.9.tar.gz"

touch zookeeper-3.4.9/conf/zoo.cfg

echo "tickTime=2000" >> zookeeper-3.4.9/conf/zoo.cfg
echo "dataDir=/var/lib/zookeeper" >> zookeeper-3.4.9/conf/zoo.cfg
echo "clientPort=2181" >> zookeeper-3.4.9/conf/zoo.cfg
echo "initLimit=5" >> zookeeper-3.4.9/conf/zoo.cfg
echo "syncLimit=2" >> zookeeper-3.4.9/conf/zoo.cfg

i=1
while [ $i -le $2 ]
do
    echo "server.$i=10.0.1.$(($i+3)):2888:3888" >> zookeeper-3.4.9/conf/zoo.cfg
    i=$(($i+1))
done

mkdir -p /var/lib/zookeeper

echo $(($1+1)) >> /var/lib/zookeeper/myid

zookeeper-3.4.9/bin/zkServer.sh start