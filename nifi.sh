#!/bin/bash

NIFI_INSTALL_ROOT=/opt
NIFI_DATA_ROOT=/nifi
DRIVENAME=/dev/sdb

createFolder() {
    if [ ! -d $1 ]; then
        sudo mkdir -p $1
    fi
}

createFolder $NIFI_DATA_ROOT

# mount extra disk

mke2fs -F -t ext4 -b 4096 -E lazy_itable_init=1 -O sparse_super,dir_index,extent,has_journal,uninit_bg -m1 $DRIVENAME
mount -o noatime,barrier=1 -t ext4 $DRIVENAME $NIFI_DATA_ROOT
UUID=`sudo lsblk -no UUID $DRIVENAME`
echo "UUID=$UUID   $NIFI_DATA_ROOT    ext4   defaults,noatime,barrier=0 0 1" | sudo tee -a /etc/fstab

NIFI_DATA_DIR=/nifi/data
NIFI_VERSION=1.3.0

# install Java 8
cd /tmp
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u144-b01/090f390dda5b47b9b721c7dfaa008135/jdk-8u144-linux-x64.rpm"
yum -y localinstall jdk-8u144-linux-x64.rpm

# Install NiFi
cd $NIFI_INSTALL_ROOT
wget http://www-eu.apache.org/dist/nifi/$NIFI_VERSION/nifi-$NIFI_VERSION-bin.tar.gz
tar -xvzf nifi-$NIFI_VERSION-bin.tar.gz
rm nifi-$NIFI_VERSION-bin.tar.gz

NIFI_HOME_DIR=$NIFI_INSTALL_ROOT/nifi-$NIFI_VERSION

createNiFiFolders() {
    CONFIGURATION=$NIFI_DATA_DIR/configuration
    createFolder $CONFIGURATION
    createFolder $CONFIGURATION/custom_lib
    REPOSITORIES=$NIFI_DATA_DIR/repositories
    createFolder $REPOSITORIES
    createFolder $REPOSITORIES/database_repository
    createFolder $REPOSITORIES/flowfile_repository
    createFolder $REPOSITORIES/content_repository
    createFolder $REPOSITORIES/provenance_repository
}

createNiFiFolders

# set config files

# nifi.properties
sed -i "s/\(nifi\.flow\.configuration\.file=\).*/\1$(($NIFI_DATA_DIR))\/configuration\/flow\.xml\.gz/" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.flow\.configuration\.archive\.dir=\).*/\1$(($NIFI_DATA_DIR))\/configuration\/archive/" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.database\.directory=\).*/\1$(($NIFI_DATA_DIR))\/repositories\/database_repository/" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.flowfile\.repository\.directory=\).*/\1$(($NIFI_DATA_DIR))\/repositories\/flowfile_repository/" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.content\.repository\.directory\.default=\).*/\1$(($NIFI_DATA_DIR))\/repositories\/content_repository/" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.provenance\.repository\.directory\.default=\).*/\1$(($NIFI_DATA_DIR))\/repositories\/provenance_repository/" $NIFI_HOME_DIR/conf/nifi.properties

sed -i "s/\(nifi\.web\.http\.host=\).*/\1nifi$(($1))/g" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.zookeeper\.connect\.string=\).*/\1zookeeper0:2181,zookeeper1:2181,zookeeper2:2181/g" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.cluster\.is\.node=\).*/\1true/g" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.cluster\.node\.address=\).*/\1nifi$(($1))/g" $NIFI_HOME_DIR/conf/nifi.properties
sed -i "s/\(nifi\.cluster\.node\.protocol\.port=\).*/\112000/g" $NIFI_HOME_DIR/conf/nifi.properties


$NIFI_HOME_DIR/bin/nifi.sh start
