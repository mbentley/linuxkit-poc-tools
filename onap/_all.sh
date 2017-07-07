#!/bin/bash

set -e

execute() {
  for APP in ${APPS}
  do
    "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/"${APP}".sh "${1}"
  done
}

main() {
  case $1 in
    launch)
      APPS="sdc aai"
      execute "${1}"
      ;;
    remove)
      APPS="aai sdc"
      execute "${1}"
      ;;
    *)
      echo "Usage: $0 {launch|remove}"
      exit 1
      ;;
  esac
}

main "${@}"
