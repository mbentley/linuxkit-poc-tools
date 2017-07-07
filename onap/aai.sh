#!/bin/bash

set -e

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=aai -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=aai -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=aai -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=aai -q) || true
}

launch() {
  # aai
  echo -e "\nCreating network..."
  docker network create --label app=aai --label onap=1 --driver bridge onap-aai

  echo -e "\nCreating volumes..."
  docker volume create --label app=aai --label onap=1 --driver local aai-logroot

  ## hbase
  echo -e "\nLaunching hbase..."
  docker run -d --name hbase \
    --label onap=1 \
    --label app=aai \
    --net onap-aai \
    -p 8020 \
    dtr.att.dckr.org/onap/aai-hbase-1.2.3:latest

  ## aai
  echo -e "\nLaunching aai-service..."
  docker run -d --name aai-service \
    --label onap=1 \
    --label app=aai \
    --net onap-aai \
    -p 8080 \
    -p 8443 \
    -e AAI_REPO_PATH=r/aai \
    -e AAI_CHEF_ENV=simpledemo \
    -e AAI_CHEF_LOC=/var/chef/aai-data/environments \
    -e docker_gitbranch=release-1.0.0 \
    -e DEBIAN_FRONTEND=noninteractive \
    -e JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/aai/etc/ssl/certs:/etc/ssl/certs \
    -v aai-logroot:/opt/aai/logroot \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/aai/aai-config:/var/chef/aai-config \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/aai/aai-data:/var/chef/aai-data \
    dtr.att.dckr.org/onap/ajsc-aai:1.0-STAGING-latest
    #-v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/aai/opt/aai/logroot:/opt/aai/logroot \

  ## model-loader
  echo -e "\nLaunching model-loader..."
  docker create --name model-loader \
    --label onap=1 \
    --label app=aai \
    --net onap-aai \
    -p 8080 \
    -p 8443 \
    -e DISTR_CLIENT_ASDC_ADDRESS=sdc-be.onap-sdc:8443 \
    -e DISTR_CLIENT_ENVIRONMENT_NAME=OBF:1ks51l8d1o3i1pcc1r2r1e211r391kls1pyj1z7u1njf1lx51go21hnj1y0k1mli1sop1k8o1j651vu91mxw1vun1mze1vv11j8x1k5i1sp11mjc1y161hlr1gm41m111nkj1z781pw31kku1r4p1e391r571pbm1o741l4x1ksp \
    -e APP_SERVER_BASE_URL=https://aai-service.onap-aai:8443 \
    -e APP_SERVER_KEYSTORE_PASSWORD=OBF:1i9a1u2a1unz1lr61wn51wn11lss1unz1u301i6o \
    -e APP_SERVER_AUTH_USER=ModelLoader \
    -e APP_SERVER_AUTH_PASSWORD=OBF:1qvu1v2h1sov1sar1wfw1j7j1wg21saj1sov1v1x1qxw \
    dtr.att.dckr.org/onap/model-loader:1.0-STAGING-latest
  docker network connect onap-sdc model-loader
  docker start model-loader
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
