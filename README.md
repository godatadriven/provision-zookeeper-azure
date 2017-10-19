## Create a Zookeeper cluster on Ubuntu VMs

Create:

- virtual network
- Zookeeper cluster
- NiFi cluster

 <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fgodatadriven%2Fprovision-zookeeper-azure%2Fmaster%2Fazuredeploy.json" target="_blank">
                                  <img src="http://azuredeploy.net/deploybutton.png"/>
                              </a>
  

This template creates a 'n' node Zookeeper cluster on CentOS 7.3 VMs. Use the 'zookeeperNodeNumber' parameter to specify the number of nodes in the cluster.

It also creates an 'n' node NiFi cluster which uses the Zookeeper cluster. These machines are also using Centos 7.3
We use the 'nifiNodeNumber' parameter to specify how many NiFi nodes there will be.
The NiFi cluster is secured using certificates. 

We obtain the NiFi admin and host certificate from a keyvault, so before we deploy this template, we need to create the keyvault and the certificates.

Creating the keyvault and enable it for deployments:

    az keyvault create --name nifiCerts --enabled-for-deployment true --resource-group <resource_group>

Create the NiFi Admin certificate and import to KeyVault:

    openssl req -x509 -newkey rsa:2048 -keyout admin-private-key.pem -out admin-cert.pem -days 365 -subj "/CN=NiFi Admin/C=NL/L=Utrecht" -nodes
    openssl pkcs12 -inkey admin-private-key.pem -in admin-cert.pem -export -out admin-user.pfx -passout pass:'your_password'
    az keyvault certificate import --vault-name nifiCerts --name adminCert --file ./admin-user.pfx --password 'your_password'
    
Deploy the machines. This won't start NiFi, because we need to add the certificates to the NiFi machines.

On a machine download the tls-toolkit (https://www.apache.org/dyn/closer.lua?path=/nifi/1.4.0/nifi-toolkit-1.4.0-bin.tar.gz). Unpack it and generate certificates for your machines:


    ./bin/tls-toolkit.sh standalone -n 'nifi[0-2]' -C 'CN=admin,OU=NIFI' -O -o ../security_output
    
Now make sure that you copy the correct certificates to the correct machines (i.e. keystore.jks and truststore.jks from the nifi<x> folder should be copied to nifi<X> machine ). On the nifi<X> machine you need to do the following:

- copy keystore.jks and truststore.jks to /opt/nifi-1.3.0/conf
- `chown root:root /opt/nifi-1.3.0/conf/*.jks`
- open the nifi.properties file on the machine and add the keystore and truststore properies which were generated in the nifi<X>/nifi.properties file on the machine where you ran the tsl-toolkit command. You'll have to adjust the following propertiesL

    nifi.security.keystorePasswd=<password>
    nifi.security.keyPasswd=<password>
    nifi.security.truststorePasswd=<password>
    
- add the admin user (whose credentials we received from the keyvault to the truststore). To do this you will need the truststore password of the given machine:

    adminCertFile=`grep -l 'subject=/CN=NiFi Admin' /var/lib/waagent/*.crt`		
    keytool -importcert -v -trustcacerts -alias 'NiFi Admin' -file $adminCertFile -keystore /opt/nifi-1.3.0/conf/truststore.jks 
         
- start nifi on each machine

    /opt/nifi-1.3.0/bin/nifi.sh start
  
 