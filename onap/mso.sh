#!/bin/bash

set -e

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=mso -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=mso -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=mso -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=mso -q) || true
}

launch() {
  # mso
  echo -e "\nCreating network..."
  docker network create --label app=mso --label onap=1 --driver bridge onap-mso

  echo -e "\nCreating volumes..."
  docker volume create --label app=mso --label onap=1 --driver local mso-mariadb

  ## mariadb
  echo -e "\nLaunching mariadb..."
  docker run -d --name mariadb \
    --label onap=1 \
    --label app=mso \
    --net onap-mso \
    -p 30252:3306 \
    -e MYSQL_ROOT_PASSWORD=password \
    -e MARIADB_MAJOR="10.1" \
    -e MARIADB_VERSION="10.1.11+maria-1~jessie" \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/mso/mariadb/conf.d:/etc/mysql/conf.d \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/mso/mariadb/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
    -v mso-mariadb:/var/lib/mysql \
    dtr.att.dckr.org/onap/mariadb:10.1.11

  ## mso
  echo -e "\nLaunching mso..."
  docker run -d --name mso \
    --label onap=1 \
    --label app=mso \
    --net onap-mso \
    -p 30225:3904 \
    -p 30224:3905 \
    -p 30223:8080 \
    -p 30222:9990 \
    -p 30250:8787 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/mso/mso:/shared \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/mso/docker-files:/docker-files \
    dtr.att.dckr.org/onap/mso:1.0-STAGING-latest \
      /docker-files/scripts/start-jboss-server.sh
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
