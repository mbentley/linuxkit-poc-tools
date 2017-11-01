onaplaunch
==========

## Stand up instructions
This example is using Ubuntu 16.04 for the servers but other operating systems can be used as long as they are supported by Docker EE (RHEL, CentOS, SLES, Oracle Linux, Ubuntu)

 * 5 nodes (4 vCPU, 15 GB RAM, 40 GB disk)
 * Nodes should have static IPs and in a lab, all ports open between the nodes for ease of installation
 * Get a 30 day Docker EE trial from https://store.docker.com/search?architecture=amd64&offering=enterprise&operating_system=linux&platform=server&q=&type=edition
 * Install Docker EE on each node:

```bash
export DOCKERURL='<DOCKER-EE-URL>'
sh -c 'echo "$DOCKERURL/centos" > /etc/yum/vars/dockerurl'
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo "$DOCKERURL/centos/docker-ee.repo"
yum -y install docker-ee
mkdir /etc/docker
echo '{"storage-driver": "overlay2", "storage-opts": ["overlay2.override_kernel_check=true"]}' > /etc/docker/daemon.json
systemctl enable docker
systemctl start docker
```

On the 2nd node (the first worker), set a label to indicate scheduling for the frontend specific components:

```bash
echo '{"storage-driver": "overlay2", "storage-opts": ["overlay2.override_kernel_check=true"],"labels": ["frontend=true"]}' > /etc/docker/daemon.json
systemctl restart docker
```

Install UCP on the manager (1st node):

```bash
# these assume that the host will have a private IP and a public IP like an AWS instance; if that isn't the case, either get rid of the --san or include a FQDN
HOST_ADDRESS="<private ip of manager>"
PUBLIC_IP="<public IP of the manager>"

docker container run --rm -it --name ucp \
  -v /var/run/docker.sock:/var/run/docker.sock \
  docker/ucp:2.2.3 install \
  --host-address ${HOST_ADDRESS} \
  --san ${PUBLIC_IP} \
  --admin-username admin \
  --admin-password docker123 \
  --interactive
```

Join the remaining workers to cluster (nodes 2-5):

```bash
docker swarm join --token <swarm-join-token> <manager-ip>:2377
```

Install nfs-utils to the UCP manager (1st node) and create NFS shares (this isn't secure at all but I do not know their IP address scheme) and export the data shares:

```bash
yum install nfs-utils
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
mkdir /data /shared_data
echo '/data *(rw,no_root_squash,no_subtree_check)' >> /etc/exports
echo '/shared_data *(rw,no_root_squash,no_subtree_check)' >> /etc/exports
exportfs -a
```

Install the nfs-utils package to the remaining nodes in the cluster (nodes 2-5):

```bash
yum install nfs-utils
```

From the manager (1st node), get a client bundle from UCP and source it:

```bash
cd ~
mkdir ucp-bundle
cd ucp-bundle
apt-get install -y jq unzip
USERNAME="admin"
PASSWORD="docker123"
UCP_URL="<public_ip_of_UCP>"
AUTH_TOKEN="$(curl -sk -d '{"username":"'${USERNAME}'","password":"'${PASSWORD}'"}' https://${UCP_URL}/auth/login | jq -r .auth_token 2>/dev/null)"
curl -sk -H "Authorization: Bearer ${AUTH_TOKEN}" https://${UCP_URL}/api/clientbundle -o bundle.zip
unzip bundle.zip
eval $(<env.sh)
```

From the manager (1st node), clone the linuxkit-poc-tools repo and run the deployment script from the UCP manager:

```bash
cd ~
git clone https://github.com/mbentley/linuxkit-poc-tools.git
cd linuxkit-poc-tools/onaplaunch

./_all.sh launch
```

From the manager (1st node), verify that the frontend services are all running on the node with the frontend=true label:

```bash
# docker ps -f name=pap -f name=vid-server -f name=portalapps -f name=sdc-fe --format 'table {{.Names}}\t{{.Ports}}'
NAMES                        PORTS
ip-172-31-25-88/pap          172.31.25.88:8443->8443/tcp, 172.31.25.88:30218->9091/tcp
ip-172-31-25-88/vid-server   172.31.25.88:8080->8080/tcp
ip-172-31-25-88/portalapps   172.31.25.88:30213->8005/tcp, 172.31.25.88:30214->8009/tcp, 172.31.25.88:8989->8080/tcp
ip-172-31-25-88/sdc-fe       8080/tcp, 172.31.25.88:8181->8181/tcp, 172.31.25.88:30207->9443/tcp
```

In my case, 172.31.25.88 has a public IP of 52.90.171.185 so my hosts file has the following added (on my workstation):

```bash
52.90.171.185 policy.api.simpledemo.openecomp.org
52.90.171.185 portal.api.simpledemo.openecomp.org
52.90.171.185 sdc.api.simpledemo.openecomp.org
52.90.171.185 sdc.ui.simpledemo.openecomp.org
52.90.171.185 vid.api.simpledemo.openecomp.org
```
