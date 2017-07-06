# sdc
docker network create -d bridge sdc

## sdc-es
docker run -d --name sdc-es \
  --net sdc \
  -p 9200:9200 \
  -p 9300:9300 \
  -e ENVNAME=AUTO \
  -e HOST_IP=172.31.4.207 \
  -e ES_HEAP_SIZE=1024M \
  -v /etc/localtime:/etc/localtime \
  -v ${HOME}/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
  -v sdc-es:/usr/share/elasticsearch/data \
  -v sdc-logs:/var/lib/jetty/logs \
  dtr.att.dckr.org/onap/sdc-elasticsearch:1.0-STAGING-latest

## sdc-cs
docker run -d --name sdc-cs \
  --net sdc \
  -p 9042:9042 \
  -p 9160:9160 \
  -e ENVNAME=AUTO \
  -e HOST_IP=172.31.4.207 \
  -e ES_HEAP_SIZE=1024M \
  -v /etc/localtime:/etc/localtime \
  -v /dockerdata-nfs/onapdemo/sdc/sdc-cs/CS:/var/lib/cassandra \
  -v ${HOME}/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
  -v sdc-logs:/var/lib/jetty/logs \
  dtr.att.dckr.org/onap/sdc-cassandra:1.0-STAGING-latest

## sdc-kb
docker run -d --name sdc-kb \
  --net sdc \
  -p 5601:5601 \
  -e ENVNAME=AUTO \
  -e ELASTICSEARCH_URL=http://sdc-es:9200 \
  -v /etc/localtime:/etc/localtime \
  -v ${HOME}/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
  -v sdc-logs:/var/lib/jetty/logs \
  dtr.att.dckr.org/onap/sdc-kibana:1.0-STAGING-latest

## sdc-be
docker run -d --name sdc-be \
  --net sdc \
  -p 8080:8080 \
  -p 8443:8443 \
  -e ENVNAME=AUTO \
  -e HOST_IP=172.31.4.207 \
  -v /etc/localtime:/etc/localtime \
  -v ${HOME}/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
  -v ${HOME}/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/jetty/keystore:/var/lib/jetty/etc/keystore \
  -v sdc-es:/usr/share/elasticsearch/data \
  -v sdc-logs:/var/lib/jetty/logs \
  dtr.att.dckr.org/onap/sdc-backend:1.0-STAGING-latest

## sdc-fe
docker run -it --rm --name sdc-fe \
  --net sdc \
  -p 8181:8181 \
  -p 9443:9443 \
  -e ENVNAME=AUTO \
  -e HOST_IP=172.31.4.207 \
  -v /etc/localtime:/etc/localtime \
  -v ${HOME}/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
  -v ${HOME}/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/jetty/keystore:/var/lib/jetty/etc/keystore \
  -v ${HOME}/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/sdc-fe/FE_2_setup_configuration.rb:/root/chef-solo/cookbooks/sdc-catalog-fe/recipes/FE_2_setup_configuration.rb \
  -v sdc-es:/usr/share/elasticsearch/data \
  -v sdc-logs:/var/lib/jetty/logs \
  dtr.att.dckr.org/onap/sdc-frontend:1.0-STAGING-latest
