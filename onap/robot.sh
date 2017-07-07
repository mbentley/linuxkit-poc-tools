#!/bin/bash

set -e

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=robot -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=robot -qa) || true

  #echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  #docker volume rm $(docker volume ls -f label=app=robot -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=robot -q) || true
}

launch() {
  # robot
  echo -e "\nCreating network..."
  docker network create --label app=robot --label onap=1 --driver bridge onap-robot

  #echo -e "\nCreating volumes..."
  #docker volume create --label app=robot --label onap=1 --driver local aai-logroot

  ## robot
  echo -e "\nLaunching robot..."
  docker run -d --name robot \
    --label onap=1 \
    --label app=robot \
    --net onap-robot \
    -p 88 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/robot/eteshare:/share \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/robot/robot/aassets:/var/opt/OpenECOMP_ETE/robot/assets \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/robot/robot/resources:/var/opt/OpenECOMP_ETE/robot/resources \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/robot/robot/testsuites:/var/opt/OpenECOMP_ETE/robot/testsuites \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/robot/authorization:/etc/lighttpd/authorization \
    dtr.att.dckr.org/onap/testsuite:1.0-STAGING-latest
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
