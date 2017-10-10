#!/bin/bash

set -e

CONFIG_HOME="${CONFIG_HOME:-"${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config}"

# figure out host ip
DEFAULT_IFACE=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
DEFAULT_IP="$(ip addr show dev "${DEFAULT_IFACE}" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')"

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
  docker network create --label app=sdc --label onap=1 --driver bridge onap-sdc

  echo -e "\nCreating volumes..."
  docker volume create --label app=sdc --label onap=1 --driver local sdc-es
  docker volume create --label app=sdc --label onap=1 --driver local sdc-cs
  docker volume create --label app=sdc --label onap=1 --driver local sdc-cs-logs
  docker volume create --label app=sdc --label onap=1 --driver local sdc-logs

  echo -e "\nSetting volume permissions for Jetty..."
  chown -R 999:999 "$(docker volume inspect --format '{{.Mountpoint}}' sdc-logs)"

  ## sdc-es
  echo -e "\nLaunching sdc-es..."
  docker run -d --name sdc-es \
    --label onap=1 \
    --label app=sdc \
    --net onap-sdc \
    -p 9200 \
    -p 9300 \
    -e ENVNAME=AUTO \
    -e HOST_IP="${DEFAULT_IP}" \
    -e ES_HEAP_SIZE=1024M \
    -v /etc/localtime:/etc/localtime \
    -v "${CONFIG_HOME}"/sdc/environments:/root/chef-solo/environments \
    -v sdc-es:/usr/share/elasticsearch/data \
    -v sdc-logs:/var/lib/jetty/logs \
    linuxkitpoc/sdc-elasticsearch:1.0-STAGING-latest

  echo "Wait 15 seconds for sdc-cs to come up..."
  sleep 30

  ## sdc-cs
  echo -e "\nLaunching sdc-cs..."
  docker run -d --name sdc-cs \
    --label onap=1 \
    --label app=sdc \
    --net onap-sdc \
    -p 9042:9042 \
    -p 9160 \
    -e ENVNAME=AUTO \
    -e HOST_IP="${DEFAULT_IP}" \
    -e ES_HEAP_SIZE=1024M \
    -v /etc/localtime:/etc/localtime \
    -v sdc-cs:/var/lib/cassandra \
    -v sdc-cs-logs:/var/log/cassandra \
    -v "${CONFIG_HOME}"/sdc/environments:/root/chef-solo/environments \
    -v sdc-logs:/var/lib/jetty/logs \
    linuxkitpoc/sdc-cassandra:1.0-STAGING-latest

  echo "Wait 30 seconds for sdc-cs to come up..."
  sleep 30

  ## sdc-kb
  echo -e "\nLaunching sdc-kb..."
  docker run -d --name sdc-kb \
    --label onap=1 \
    --label app=sdc \
    --net onap-sdc \
    -p 5601 \
    -e ENVNAME=AUTO \
    -e ELASTICSEARCH_URL=http://sdc-es:9200 \
    -v /etc/localtime:/etc/localtime \
    -v "${CONFIG_HOME}"/sdc/environments:/root/chef-solo/environments \
    -v sdc-logs:/var/lib/jetty/logs \
    linuxkitpoc/sdc-kibana:1.0-STAGING-latest

  ## sdc-fe
  echo -e "\nLaunching sdc-fe..."
  docker run -d --name sdc-fe \
    --label onap=1 \
    --label app=sdc \
    --net onap-sdc \
    -p 8181:8181 \
    -p 30207:9443 \
    -e ENVNAME=AUTO \
    -e HOST_IP="${DEFAULT_IP}" \
    -v /etc/localtime:/etc/localtime \
    -v "${CONFIG_HOME}"/sdc/environments:/root/chef-solo/environments \
    -v "${CONFIG_HOME}"/sdc/jetty/keystore:/var/lib/jetty/etc/keystore \
    -v "${CONFIG_HOME}"/sdc/sdc-fe/FE_2_setup_configuration.rb:/root/chef-solo/cookbooks/sdc-catalog-fe/recipes/FE_2_setup_configuration.rb \
    -v sdc-es:/usr/share/elasticsearch/data \
    -v sdc-logs:/var/lib/jetty/logs \
    linuxkitpoc/sdc-frontend:1.0-STAGING-latest

  echo "Wait 15 seconds for the SDC services to come up..."
  sleep 15

  ## sdc-be
  echo -e "\nLaunching sdc-be..."
  docker create --name sdc-be \
    --label onap=1 \
    --label app=sdc \
    --net onap-sdc \
    -p 30205:8080 \
    -p 30204:8443 \
    -e ENVNAME=AUTO \
    -e HOST_IP=127.0.0.1 \
    -v /etc/localtime:/etc/localtime \
    -v "${CONFIG_HOME}"/sdc/environments:/root/chef-solo/environments \
    -v "${CONFIG_HOME}"/sdc/jetty/keystore:/var/lib/jetty/etc/keystore \
    -v sdc-es:/usr/share/elasticsearch/data \
    -v sdc-logs:/var/lib/jetty/logs \
    linuxkitpoc/sdc-backend:1.0-STAGING-latest
  docker network connect onap-message-router sdc-be
  docker start sdc-be

  #-e HOST_IP="${DEFAULT_IP}" \
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
