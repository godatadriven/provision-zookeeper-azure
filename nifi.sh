#!/bin/bash

NIFI_INSTALL_ROOT=/opt
NIFI_DATA_ROOT=/nifi

createFolder() {
    if [ ! -d $1 ]; then
        sudo mkdir -p $1
    fi
}

createFolder $NIFI_DATA_ROOT

prepare_disk()
{
  mount=$1
  device=$2

  FS=ext4
  FS_OPTS="-E lazy_itable_init=1"

  which mkfs.$FS
  # Fall back to ext3
  if [[ $? -ne 0 ]]; then
    FS=ext3
    FS_OPTS=""
  fi

  # is device mounted?
  mount | grep -q "${device}"
  if [ $? == 0 ]; then
    echo "$device is mounted"
  else
    echo "Warning: ERASING CONTENTS OF $device"
    mkfs.$FS -F $FS_OPTS $device -m 0

    # If $FS is ext3 or ext4, then run tune2fs -i 0 -c 0 to disable fsck checks for data volumes

    if [ $FS = "ext3" -o $FS = "ext4" ]; then
    /sbin/tune2fs -i0 -c0 ${device}
    fi

    echo "Mounting $device on $mount"
    if [ ! -e "${mount}" ]; then
      createFolder "${mount}"
    fi
    # gather the UUID for the specific device

    blockid=$(/sbin/blkid|grep ${device}|awk '{print $2}'|awk -F\= '{print $2}'|sed -e"s/\"//g")
    echo $blockid

    #mount -o defaults,noatime "${device}" "${mount}"

    # Set up the blkid for device entry in /etc/fstab

    echo "UUID=${blockid} $mount $FS defaults,noatime,discard,barrier=0 0 0" >> /etc/fstab
    mount ${mount}

  fi
}

MOUNTED_VOLUMES=$(df -h | grep -o -E "^/dev/[^[:space:]]*")
ALL_PARTITIONS=$(awk 'FNR > 2 {print $NF}' /proc/partitions)
COUNTER=0
for part in $ALL_PARTITIONS; do
  if [[ ! ${part} =~ [0-9]$ && ! ${ALL_PARTITIONS} =~ $part[0-9] && $MOUNTED_VOLUMES != *$part* ]];then
      echo ${part}
      prepare_disk "$NIFI_DATA_ROOT$COUNTER" "/dev/$part"
      COUNTER=$(($COUNTER+1))
  fi
done

# we're only interested in one disk

FIRST_DISK=/nifi0
if [ ! -d "$FIRST_DISK" ]; then
    echo "disk not mounted /nifi0 doesn't exist"
    exit -1
fi

NIFI_DATA_DIR=${FIRST_DISK}/data
NIFI_VERSION=1.4.0

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
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u151-b12/e758a0de34e24606bca991d704f6dcbf/jdk-8u151-linux-x64.rpm"
yum -y localinstall jdk-9.0.1_linux-x64_bin.rpm

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

cd $NIFI_HOME_DIR/conf

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

sed -i "s/\(nifi\.zookeeper\.connect\.string=\).*/\1zookeeper0:2181,zookeeper1:2181,zookeeper2:2181/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.cluster\.is\.node=\).*/\1true/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.cluster\.node\.address=\).*/\1nifi$(($1))/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.cluster\.node\.protocol\.port=\).*/\112000/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.zookeeper\.root\.node=\).*/\1\/root\/nifi/g" $NIFI_CONFIGURATION_FILE

sed -i "s|\(nifi\.security\.keystore=\).*|\1$NIFI_HOME_DIR\/conf\/keystore.jks|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.security\.keystoreType=\).*|\1JKS|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.security\.truststore=\).*|\1$NIFI_HOME_DIR\/conf\/truststore.jks|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.security\.truststoreType=\).*|\1JKS|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.security\.needClientAuth=\).*|\1true|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.remote\.input\.secure=\).*|\1true|g" $NIFI_CONFIGURATION_FILE
sed -i "s|\(nifi\.cluster\.protocol\.is\.secure=\).*|\1true|g" $NIFI_CONFIGURATION_FILE

sed -i "s/\(nifi\.web\.https\.host=\).*/\1nifi$(($1))/g" $NIFI_CONFIGURATION_FILE
sed -i "s/\(nifi\.web\.https\.port=\).*/\18443/g" $NIFI_CONFIGURATION_FILE

# add admin to authorized users

sed -i "s|\(property name=\"Initial Admin Identity\">\).*|\1L=Utrecht, C=NL, CN=NiFi Admin</property>|g" $NIFI_HOME_DIR/conf/authorizers.xml

for (( c=0; c<$2; c++ ))
do
    sed -i '/<\/authorizer>/i \
    <property name="Node Identity '$c'">CN=nifi'$c', OU=NIFI<\/property>
    ' $NIFI_HOME_DIR/conf/authorizers.xml
done

