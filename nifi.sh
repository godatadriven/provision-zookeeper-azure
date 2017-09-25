#!/bin/bash

NIFI_INSTALL_ROOT=/opt
NIFI_DATA_ROOT=/nifi
# we need to look up driver name for lun 0
# https://github.com/Azure/azure-sdk-for-go/issues/315
LUN_NR=0
scsiOutput=$(lsscsi)
if [[ $scsiOutput =~ \[5.*$LUN_NR\][^\[]*(/dev/sd[a-zA-Z]{1,2}) ]];
then
        DRIVENAME=${BASH_REMATCH[1]};
else
        echo "lsscsi output not as expected for $LUN_NR"
        exit -1;
fi

createFolder() {
    if [ ! -d $1 ]; then
        sudo mkdir -p $1
    fi
}

createFolder $NIFI_DATA_ROOT

# mount extra disk

mke2fs -F -t ext4 -b 4096 -E lazy_itable_init=1 -O sparse_super,dir_index,extent,has_journal,uninit_bg -m1 $DRIVENAME
UUID=`lsblk -no UUID $DRIVENAME | sed '/^$/d'`
echo "UUID=$UUID   $NIFI_DATA_ROOT    ext4   defaults,noatime,barrier=0 0 1" | tee -a /etc/fstab
mount $NIFI_DATA_ROOT

NIFI_DATA_DIR=/nifi/data
NIFI_VERSION=1.3.0

# increase number of file handles and forked processes

cat  <<EOF > /etc/security/limits.d/99-username-limits.conf
*  hard  nofile  50000
*  soft  nofile  50000
*  hard  nproc  10000
*  soft  nproc  10000
EOF

# increase the number of TCP socket ports available

sysctl -w net.ipv4.ip_local_port_range="10000 65000"

# You don’t want your sockets to sit and linger too long given that you want to be able to quickly setup and teardown new sockets.

sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait="1"

# we don't want NiFi to swap
sysctl vm.swappiness=0

echo "vm.swappiness = 0" >> /etc/sysctl.conf

sysctl -p

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

NIFI_CONFIGURATION=$NIFI_DATA_DIR/configuration
createFolder $NIFI_CONFIGURATION
createFolder $NIFI_CONFIGURATION/archive
createFolder $NIFI_CONFIGURATION/custom_lib
NIFI_REPOSITORIES=$NIFI_DATA_DIR/repositories
createFolder $NIFI_REPOSITORIES
createFolder $NIFI_REPOSITORIES/database_repository
createFolder $NIFI_REPOSITORIES/flowfile_repository
createFolder $NIFI_REPOSITORIES/content_repository
createFolder $NIFI_REPOSITORIES/provenance_repository

# set config files
NIFI_CONFIGURATION_FILE=$NIFI_HOME_DIR/conf/nifi.properties

echo -e "\nexport JAVA_HOME=\"/usr/java/latest/\"" >> $NIFI_HOME_DIR/bin/nifi-env.sh
echo -e "\nnifi.nar.library.directory.custom=$NIFI_CONFIGURATION/custom_lib" >> $NIFI_HOME/$NIFI_VERSION/conf/nifi.properties

# nifi.properties
sed -i "s|\(nifi\.flow\.configuration\.file=\).*|\1$NIFI_CONFIGURATION\/flow\.xml\.gz|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.flow\.configuration\.archive\.dir=\).*|\1$NIFI_CONFIGURATION\/archive|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.database\.directory=\).*|\1$NIFI_REPOSITORIES\/database_repository|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.flowfile\.repository\.directory=\).*|\1$NIFI_REPOSITORIES\/flowfile_repository|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.content\.repository\.directory\.default=\).*|\1$NIFI_REPOSITORIES\/content_repository|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.provenance\.repository\.directory\.default=\).*|\1$NIFI_REPOSITORIES\/provenance_repository|g" $NIFI_CONFIGURATION_FILE

sed -i "s/\(nifi\.web\.http\.host=\).*/\10.0.0.0/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.zookeeper\.connect\.string=\).*/\1zookeeper0:2181,zookeeper1:2181,zookeeper2:2181/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.cluster\.is\.node=\).*/\1true/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.cluster\.node\.address=\).*/\1nifi$(($1))/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.cluster\.node\.protocol\.port=\).*/\112000/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.zookeeper\.root\.node=\).*/\1nifi$(($1))/g" $NIFI_CONFIGURATION_FILE


$NIFI_HOME_DIR/bin/nifi.sh start
