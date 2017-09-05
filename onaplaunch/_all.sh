#!/bin/bash

set -e

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
  if [ ! -d "${HOME}/git/oom" ]
  then
    docker run --rm -v /root:/root linuxkitpoc/oomclone:latest
  fi
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
