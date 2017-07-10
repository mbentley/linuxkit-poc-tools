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
      APPS="sdc mso message-router aai robot portal vid"
      execute "${1}"
      ;;
    remove)
      APPS="vid portal robot aai message-router mso sdc"
      execute "${1}"
      ;;
    *)
      echo "Usage: $0 {launch|remove}"
      exit 1
      ;;
  esac
}

main "${@}"
