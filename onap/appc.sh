#!/bin/bash

set -e

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=appc -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=appc -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=appc -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=appc -q) || true
}

launch() {
  # appc
  echo -e "\nCreating network..."
  docker network create --label app=appc --label onap=1 --driver bridge onap-appc

  echo -e "\nCreating volumes..."
  docker volume create --label app=appc --label onap=1 --driver local appc-data

  ## appc-dbhost
  echo -e "\nLaunching appc-dbhost..."
  docker run -d --name appc-dbhost \
    --label onap=1 \
    --label app=appc \
    --net onap-appc \
    --network-alias dbhost \
    --network-alias sdnctldb01 \
    --network-alias sdnctldb02 \
    -p 3306 \
    -e MYSQL_ROOT_PASSWORD="openECOMP1.0" \
    -e MYSQL_ROOT_HOST='%' \
    -v appc-data:/var/lib/mysql \
    dtr.att.dckr.org/onap/mysql-server:5.6

  ## appc-dgbuilder-container
  echo -e "\nLaunching appc-dgbuilder-container..."
  docker run -td --name appc-dgbuilder-container \
    --label onap=1 \
    --label app=appc \
    --net onap-appc \
    -p 30228:3100 \
    -e MYSQL_ROOT_PASSWORD="openECOMP1.0" \
    -e SDNC_CONFIG_DIR=/opt/openecomp/appc/data/properties \
    -e APPC_CONFIG_DIR=/opt/openecomp/appc/data/properties \
    dtr.att.dckr.org/onap/dgbuilder-sdnc-image:1.0-STAGING-latest \
      /bin/bash -c 'cd /opt/openecomp/sdnc/dgbuilder/ && ./start sdnc1.0 && wait'

  ## appc
  echo -e "\nLaunching appc-controller-container..."
  docker run -d --name appc-controller-container \
    --label onap=1 \
    --label app=appc \
    --net onap-appc \
    -p 30230:8181 \
    -p 30231:1830 \
    -e MYSQL_ROOT_PASSWORD="openECOMP1.0" \
    -e SDNC_CONFIG_DIR=/opt/openecomp/appc/data/properties \
    -e APPC_CONFIG_DIR=/opt/openecomp/appc/data/properties \
    -e DMAAP_TOPIC_ENV=SUCCESS \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/appc/conf:/opt/openecomp/appc/data/properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdnc/conf:/opt/openecomp/sdnc/data/properties \
    dtr.att.dckr.org/onap/appc-image:1.0-STAGING-latest \
      /opt/openecomp/appc/bin/startODL.sh
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
