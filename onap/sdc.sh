#!/bin/bash

set -e

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=sdc -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=sdc -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=sdc -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=sdc -q) || true

}

launch() {
  # sdc
  echo -e "\nCreating network..."
  docker network create --label app=sdc --driver bridge onap-sdc

  echo -e "\nCreating volumes..."
  docker volume create --label app=sdc --driver local sdc-es
  docker volume create --label app=sdc --driver local sdc-logs

  ## sdc-es
  echo -e "\nLaunching sdc-es..."
  docker run -d --name sdc-es \
    --label app=sdc \
    --net onap-sdc \
    -p 9200:9200 \
    -p 9300:9300 \
    -e ENVNAME=AUTO \
    -e HOST_IP=172.31.4.207 \
    -e ES_HEAP_SIZE=1024M \
    -v /etc/localtime:/etc/localtime \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
    -v sdc-es:/usr/share/elasticsearch/data \
    -v sdc-logs:/var/lib/jetty/logs \
    dtr.att.dckr.org/onap/sdc-elasticsearch:1.0-STAGING-latest

  ## sdc-cs
  echo -e "\nLaunching sdc-cs..."
  docker run -d --name sdc-cs \
    --label app=sdc \
    --net onap-sdc \
    -p 9042:9042 \
    -p 9160:9160 \
    -e ENVNAME=AUTO \
    -e HOST_IP=172.31.4.207 \
    -e ES_HEAP_SIZE=1024M \
    -v /etc/localtime:/etc/localtime \
    -v /dockerdata-nfs/onapdemo/sdc/sdc-cs/CS:/var/lib/cassandra \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
    -v sdc-logs:/var/lib/jetty/logs \
    dtr.att.dckr.org/onap/sdc-cassandra:1.0-STAGING-latest

  ## sdc-kb
  echo -e "\nLaunching sdc-kb..."
  docker run -d --name sdc-kb \
    --label app=sdc \
    --net onap-sdc \
    -p 5601:5601 \
    -e ENVNAME=AUTO \
    -e ELASTICSEARCH_URL=http://sdc-es:9200 \
    -v /etc/localtime:/etc/localtime \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
    -v sdc-logs:/var/lib/jetty/logs \
    dtr.att.dckr.org/onap/sdc-kibana:1.0-STAGING-latest

  ## sdc-fe
  echo -e "\nLaunching sdc-fe..."
  docker run -d --name sdc-fe \
    --label app=sdc \
    --net onap-sdc \
    -p 8181:8181 \
    -p 9443:9443 \
    -e ENVNAME=AUTO \
    -e HOST_IP=172.31.4.207 \
    -v /etc/localtime:/etc/localtime \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/jetty/keystore:/var/lib/jetty/etc/keystore \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/sdc-fe/FE_2_setup_configuration.rb:/root/chef-solo/cookbooks/sdc-catalog-fe/recipes/FE_2_setup_configuration.rb \
    -v sdc-es:/usr/share/elasticsearch/data \
    -v sdc-logs:/var/lib/jetty/logs \
    dtr.att.dckr.org/onap/sdc-frontend:1.0-STAGING-latest

  #echo "Waiting for services to initialize (this is a sad hack)..."
  #sleep 30

  ## sdc-be
  echo -e "\nLaunching sdc-be..."
  docker run -d --name sdc-be \
    --label app=sdc \
    --net onap-sdc \
    -p 8080:8080 \
    -p 8443:8443 \
    -e ENVNAME=AUTO \
    -e HOST_IP=172.31.4.207 \
    -v /etc/localtime:/etc/localtime \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/environments:/root/chef-solo/environments \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdc/jetty/keystore:/var/lib/jetty/etc/keystore \
    -v sdc-es:/usr/share/elasticsearch/data \
    -v sdc-logs:/var/lib/jetty/logs \
    dtr.att.dckr.org/onap/sdc-backend:1.0-STAGING-latest
}

main() {
  case $1 in
    launch|remove)
      ${1}
      ;;
    *)
      echo "Usage: $0 {launch|remove}"
      exit 1
      ;;
  esac
}

main "${@}"
