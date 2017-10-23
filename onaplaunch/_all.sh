#!/bin/bash

set -e

# set CONFIG_HOME, NFS_HOST, and LOCAL_VOLUME_OPTS
export CONFIG_HOME="${CONFIG_HOME:-/data/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config}"
export NFS_HOST="${NFS_HOST:-}"
if [ ! -z "${NFS_HOST}" ]
then
  export LOCAL_VOLUME_OPTS="--opt type=nfs --opt o=addr=${NFS_HOST},rw,hard,intr,sync,actimeo=0 --opt device=:/shared_data"
else
  echo "Missing NFS_HOST variable"
  exit 1
fi

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

main() {
  case $1 in
    launch)
      clone
      APPS="message-router sdc mso aai robot portal vid sdnc policy appc"
      execute "${1}"
      ;;
    remove)
      APPS="appc policy sdnc vid portal robot aai mso sdc message-router"
      execute "${1}"
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
