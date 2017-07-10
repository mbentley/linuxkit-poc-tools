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

main() {
  case $1 in
    launch)
      APPS="message-router sdc mso aai robot portal vid sdnc appc"
      execute "${1}"
      ;;
    remove)
      APPS="appc sdnc vid portal robot aai mso sdc message-router"
      execute "${1}"
      ;;
    *)
      echo "Usage: $0 {launch|remove}"
      exit 1
      ;;
  esac
}

main "${@}"
