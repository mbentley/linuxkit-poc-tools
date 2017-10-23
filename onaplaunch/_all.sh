#!/bin/bash

set -e

# set CONFIG_HOME, NFS_HOST, and LOCAL_VOLUME_OPTS
export CONFIG_HOME="${CONFIG_HOME:-/data/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config}"
export NFS_HOST="${NFS_HOST:-}"
if [ -z "${NFS_HOST}" ]
then
  # figure out the default interface and use that
  DEFAULT_IFACE=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
  NFS_HOST="$(ip addr show dev "${DEFAULT_IFACE}" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')"
fi

export LOCAL_VOLUME_OPTS="--opt type=nfs --opt o=addr=${NFS_HOST},rw,hard,intr,sync,actimeo=0,nolock --opt device=:/shared_data"

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
}

datadirs() {
  # create data directories
  if [ ! -d "/shared_data" ]
  then
    echo "Creating /shared_data..."
    mkdir /shared_data
  else
    echo "Shared data directory '/shared_data' already exists."
  fi

  (cd /shared_data &&\
    mkdir aai-logroot appc-data message-router-zk-conf message-router-data-kafka mso-mariadb policy-data policy-data2 nexus-data portal-mariadb-data portal-ubuntu-init portalapps-logs sdc-es sdc-cs sdc-cs-logs sdc-logs sdnc-data vid-mariadb-data)
}

cleanup() {
  # clear data
  (cd /shared_data &&\
    rm -rf ./*)
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
