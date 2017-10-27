#!/bin/bash

set -e

# initialize
# shellcheck disable=SC1090
. "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/init.sh"

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=vid -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=vid -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=vid -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=vid -q) || true
}

launch() {
  # vid
  echo -e "\nCreating network..."
  docker network create --label app=vid --label onap=1 --driver overlay --attachable onap-vid

  echo -e "\nCreating volumes..."
  #shellcheck disable=2086
  docker volume create --label app=vid --label onap=1 --driver local ${LOCAL_VOLUME_OPTS}/vid-mariadb-data vid-mariadb-data

  ## vid-mariadb
  echo -e "\nLaunching vid-mariadb..."
  docker run -d --name vid-mariadb \
    --label onap=1 \
    --label app=vid \
    --net onap-vid \
    -p 3306 \
    -e MYSQL_DATABASE=vid_openecomp \
    -e MYSQL_USER=vidadmin \
    -e MYSQL_PASSWORD=Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U \
    -e MYSQL_ROOT_PASSWORD=LF+tp_1WqgSY \
    -v vid-mariadb-data:/var/lib/mysql \
    -v "${CONFIG_HOME}"/vid/vid/lf_config/vid-pre-init.sql:/docker-entrypoint-initdb.d/vid-pre-init.sql \
    -v "${CONFIG_HOME}"/vid/vid/lf_config/vid-my.cnf:/etc/mysql/my.cnf \
    linuxkitpoc/mariadb:10

  ## vid
  echo -e "\nLaunching vid-server..."
  docker create --name vid-server \
    --label onap=1 \
    --label app=vid \
    --net onap-vid \
    -p 8080:8080 \
    -e constraint:frontend==true \
    -e ASDC_CLIENT_REST_HOST=sdc-be.onap-sdc \
    -e ASDC_CLIENT_REST_AUTH="Basic dmlkOktwOGJKNFNYc3pNMFdYbGhhazNlSGxjc2UyZ0F3ODR2YW9HR21KdlV5MlU=" \
    -e ASDC_CLIENT_REST_PORT=8080 \
    -e VID_AAI_HOST=aai-service.onap-aai \
    -e VID_AAI_PORT=8443 \
    -e VID_ECOMP_SHARED_CONTEXT_REST_URL=http://portal.api.simpledemo.openecomp.org:8989/ECOMPPORTAL/context \
    -e VID_MSO_SERVER_URL=http://mso.onap-mso:8080 \
    -e VID_MSO_PASS=51515201a8d4c5c08d533db9bd1e1a9b \
    -e MSO_DME2_SERVER_URL=http://localhost:8081 \
    -e MSO_DME2_ENABLED=false \
    -e VID_ECOMP_REDIRECT_URL=http://portal.api.simpledemo.openecomp.org:8989/ECOMPPORTAL/login.htm \
    -e VID_ECOMP_REST_URL=http://portal.api.simpledemo.openecomp.org:8989/ECOMPPORTAL/auxapi \
    -e VID_CONTACT_US_LINK=https://todo_contact_us_link.com \
    -e VID_UEB_URL_LIST=dmaap.onap-message-router \
    -e VID_MYSQL_HOST=vid-mariadb \
    -e VID_MYSQL_PORT=3306 \
    -e VID_MYSQL_DBNAME=vid_openecomp \
    -e VID_MYSQL_USER=vidadmin \
    -e VID_MYSQL_PASS=Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U \
    -e VID_MYSQL_MAXCONNECTIONS=5 \
    linuxkitpoc/vid:1.0-STAGING-latest
  docker network connect onap-aai vid-server
  docker network connect onap-sdc vid-server
  docker network connect onap-portal vid-server
  docker network connect onap-mso vid-server
  docker network connect onap-message-router vid-server
  docker start vid-server
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
