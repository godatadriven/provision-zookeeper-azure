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

Creating the keyvault and enable it for deployemnts:

    az keyvault create --name nifiCerts --enabled-for-deployment true --resource-group <resource_group>

Generate a certificate for the nodes which we can add to the truststore and keystore:

    openssl req -x509 -newkey rsa:2048 -keyout nifi-private-key.pem -out nifi-cert.pem -days 365 -subj "/CN=localhost/OU=NiFi" -nodes
    openssl pkcs12 -inkey nifi-private-key.pem -in nifi-cert.pem -export -out nifi.pfx -passout pass:'your_password'

Upload the host certificate to the keyvault:
    
    az keyvault certificate import --vault-name nifiCerts --name nifiCert --file ./nifi.pfx --password 'your_password'

Create the NiFi Admin certificate and import to KeyVault:

    openssl req -x509 -newkey rsa:2048 -keyout admin-private-key.pem -out admin-cert.pem -days 365 -subj "/CN=NiFi Admin/C=NL/L=Utrecht" -nodes
    openssl pkcs12 -inkey admin-private-key.pem -in admin-cert.pem -export -out admin-user.pfx -passout pass:'your_password'
    az keyvault certificate import --vault-name nifiCerts --name adminCert --file ./admin-user.pfx --password 'your_password'
    

#### Adding another certificate to the truststore
 
If you need to add another certificate to the NiFi server, you should generate the certificate with the above mentioned commands, then you need to copy the certificate to the servers and add it to the truststore on the servers:

    keytool -importcert -v -trustcacerts -alias username -file admin-cert.pem -keystore /opt/nifi-1.3.0/conf/server_truststore.jks  -storepass 'keystore password' -noprompt
    
After this you will need to restart the NiFi cluster.    
 