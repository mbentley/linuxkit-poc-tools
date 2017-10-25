#!/bin/bash

set -e

# initialize
# shellcheck disable=SC1090
. "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/init.sh"

# check to see if running as root
if [ "$EUID" -ne 0 ]
then
  echo "Please run as root"
  exit 1
fi

execute() {
  for APP in ${APPS}
  do
    echo "Executing '${1}' for ${APP}..."
    "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/"${APP}".sh "${1}"
    echo -e "done.\n"
  done
}

clone() {
  # check to see if service has been previously deployed
  if [ "$(docker service ls -f name=oomclone --format '{{.Name}}')" = "oomclone" ]
  then
    # service exists; remove
    docker service rm oomclone
  fi

  # clone the repo everywhere using a global service
  docker service create --tty --detach=false \
    --name oomclone \
    --mode global \
    --restart-condition none \
    --mount type=bind,source=/data,destination=/root \
    linuxkitpoc/oomclone:latest

  # TODO: this should be in the oomclone image if it should happen everywhere
  replace_values
}

replace_values() {
  cd /data/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config
  NEW_VALUE="34.230.201.217"

  for APP in policy portal sdc vid
  do
    grep -rlI ${APP}.api.simpledemo.openecomp.org ./* | while IFS= read -r FILE
    do
      echo sed -i "s/${APP}.api.simpledemo.openecomp.org/${NEW_VALUE}/g" "${FILE}"
    done
  done
}

datadirs() {
  if [ -d "/data" ]
  then
    echo "Creating data directory '/data'..."
    mkdir /data
    echo -e "done.\n"
  fi

  echo "Creating shared data directories under '/shared_data'..."
  # create data directories
  if [ ! -d "/shared_data" ]
  then
    echo "Creating /shared_data..."
    mkdir /shared_data
  else
    echo "Shared data directory '/shared_data' already exists."
  fi
  echo -e "done.\n"

  (cd /shared_data &&\
    mkdir aai-logroot appc-data message-router-zk-conf message-router-data-kafka mso-mariadb policy-data policy-data2 nexus-data portal-mariadb-data portal-ubuntu-init portalapps-logs sdc-es sdc-cs sdc-cs-logs sdc-logs sdnc-data vid-mariadb-data)
}

cleanup() {
  echo "Removing shared data directories under '/shared_data'..."
  # clear data
  (cd /shared_data &&\
    rm -rf ./*)
  echo -e "done.\n"
}

main() {
  case $1 in
    launch)
      clone
      datadirs
      APPS="message-router sdc mso aai robot portal vid sdnc policy appc"
      execute "${1}"
      ;;
    remove)
      APPS="appc policy sdnc vid portal robot aai mso sdc message-router"
      execute "${1}"
      cleanup
      ;;
    clone)
      "${1}"
      ;;
    *)
      echo "Usage: $0 {launch|remove}"
      exit 1
      ;;
  esac
}

main "${@}"
