#!/bin/bash

set -e

# initialize
# shellcheck disable=SC1090
. "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/init.sh"

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=message-router -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=message-router -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=message-router -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=message-router -q) || true
}

launch() {
  # message-router
  echo -e "\nCreating network..."
  docker network create --label app=message-router --label onap=1 --driver overlay --attachable onap-message-router

  echo -e "\nCreating volumes..."
  #shellcheck disable=2086
  docker volume create --label app=message-router --label onap=1 --driver local ${LOCAL_VOLUME_OPTS}/message-router-zk-conf message-router-zk-conf
  #shellcheck disable=2086
  docker volume create --label app=message-router --label onap=1 --driver local ${LOCAL_VOLUME_OPTS}/message-router-data-kafka message-router-data-kafka

  ## zookeeper
  echo -e "\nLaunching zookeeper..."
  docker run -d --name zookeeper\
    --label onap=1 \
    --label app=message-router \
    --net onap-message-router \
    -p 2181 \
    -v "${CONFIG_HOME}"/message-router/dcae-startup-vm-message-router/docker_files/data-zookeeper:/opt/zookeeper-3.4.9/data \
    -v message-router-zk-conf:/opt/zookeeper-3.4.9/conf \
    linuxkitpoc/zookeeper:latest

  echo "Wait 15 seconds for zookeeper to come up..."
  sleep 15

  ## global-kafka
  echo -e "\nLaunching global-kafka..."
  docker run -d --name global-kafka \
    --label onap=1 \
    --label app=message-router \
    --net onap-message-router \
    -p 9092 \
    -e KAFKA_ZOOKEEPER_CONNECT=zookeeper.onap-message-router:2181 \
    -e KAFKA_ADVERTISED_HOST_NAME=global-kafka \
    -e KAFKA_BROKER_ID=1 \
    -e KAFKA_ADVERTISED_PORT=9092 \
    -e KAFKA_PORT=9092 \
    -v "${CONFIG_HOME}"/message-router/dcae-startup-vm-message-router/docker_files/data-kafka:/kafka \
    -v "${CONFIG_HOME}"/message-router/dcae-startup-vm-message-router/docker_files/start-kafka.sh:/start-kafka.sh \
    -v /var/run/docker.sock:/var/run/docker.sock \
    linuxkitpoc/kafka:latest

  ## dmaap
  echo -e "\nLaunching dmaap..."
  docker run -d --name dmaap \
    --label onap=1 \
    --label app=message-router \
    --net onap-message-router \
    -p 30227:3904 \
    -p 30226:3095 \
    -v "${CONFIG_HOME}"/message-router/dmaap/MsgRtrApi.properties:/appl/dmaapMR1/bundleconfig/etc/appprops/MsgRtrApi.properties \
    -v "${CONFIG_HOME}"/message-router/dmaap/cadi.properties:/appl/dmaapMR1/etc/cadi.properties \
    -v "${CONFIG_HOME}"/message-router/dmaap/mykey:/appl/dmaapMR1/etc/keyfile \
    linuxkitpoc/dmaap:latest
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
