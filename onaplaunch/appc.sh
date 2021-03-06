#!/bin/bash

set -e

# initialize
# shellcheck disable=SC1090
. "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/init.sh"

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
  docker network create --label app=appc --label onap=1 --driver overlay --attachable onap-appc

  echo -e "\nCreating volumes..."
  #shellcheck disable=2086
  docker volume create --label app=appc --label onap=1 --driver local ${LOCAL_VOLUME_OPTS}/appc-data appc-data

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
    linuxkitpoc/mysql-server:5.6

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
    linuxkitpoc/dgbuilder-sdnc-image:1.0-STAGING-latest \
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
    -v "${CONFIG_HOME}"/appc/conf:/opt/openecomp/appc/data/properties \
    -v "${CONFIG_HOME}"/sdnc/conf:/opt/openecomp/sdnc/data/properties \
    linuxkitpoc/appc-image:1.0-STAGING-latest \
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
