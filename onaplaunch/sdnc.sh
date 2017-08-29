#!/bin/bash

set -e

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=sdnc -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=sdnc -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=sdnc -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=sdnc -q) || true
}

launch() {
  # sdnc
  echo -e "\nCreating network..."
  docker network create --label app=sdnc --label onap=1 --driver bridge onap-sdnc

  echo -e "\nCreating volumes..."
  docker volume create --label app=sdnc --label onap=1 --driver local sdnc-data

  ## sdnc-dbhost
  echo -e "\nLaunching sdnc-dbhost..."
  docker run -d --name sdnc-dbhost \
    --label onap=1 \
    --label app=sdnc \
    --net onap-sdnc \
    --network-alias dbhost \
    --network-alias sdnctldb01 \
    --network-alias sdnctldb02 \
    -p 3306 \
    -e MYSQL_ROOT_PASSWORD="openECOMP1.0" \
    -e MYSQL_ROOT_HOST='%' \
    -v sdnc-data:/var/lib/mysql \
    linuxkitpoc/mysql-server:5.6

  ## sdnc-dgbuilder-container
  echo -e "\nLaunching sdnc-dgbuilder-container..."
  docker run -td --name sdnc-dgbuilder-container \
    --label onap=1 \
    --label app=sdnc \
    --net onap-sdnc \
    -p 30203:3100 \
    -e MYSQL_ROOT_PASSWORD="openECOMP1.0" \
    -e SDNC_CONFIG_DIR=/opt/openecomp/sdnc/data/properties \
    linuxkitpoc/dgbuilder-sdnc-image:1.0-STAGING-latest \
      /bin/bash -c 'cd /opt/openecomp/sdnc/dgbuilder/ && ./start sdnc1.0 && wait'

  ## sdnc
  echo -e "\nLaunching sdnc-controller-container..."
  docker run -d --name sdnc-controller-container \
    --label onap=1 \
    --label app=sdnc \
    --net onap-sdnc \
    -p 30202:8181 \
    -e MYSQL_ROOT_PASSWORD="openECOMP1.0" \
    -e SDNC_CONFIG_DIR=/opt/openecomp/sdnc/data/properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdnc/conf:/opt/openecomp/sdnc/data/properties \
    linuxkitpoc/sdnc-image:1.0-STAGING-latest \
      /opt/openecomp/sdnc/bin/startODL.sh

  ## sdnc-portal-container
  echo -e "\nLaunching sdnc-portal-container..."
  docker run -d --name sdnc-portal-container \
    --label onap=1 \
    --label app=sdnc \
    --net onap-sdnc \
    -p 30201:8843 \
    -e MYSQL_ROOT_PASSWORD="openECOMP1.0" \
    -e SDNC_CONFIG_DIR=/opt/openecomp/sdnc/data/properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/sdnc/conf:/opt/openecomp/sdnc/data/properties \
    linuxkitpoc/admportal-sdnc-image:1.0-STAGING-latest \
      /bin/bash -c 'cd /opt/openecomp/sdnc/admportal/shell && ./start_portal.sh'
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
