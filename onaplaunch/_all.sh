#!/bin/bash

set -e

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
    docker run --rm -v /root:/root dtr.att.dckr.org/services/oomclone:latest
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
