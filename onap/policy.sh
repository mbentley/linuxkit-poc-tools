#!/bin/bash

set -e

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=policy -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=policy -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=policy -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=policy -q) || true
}

launch() {
  # policy
  echo -e "\nCreating network..."
  docker network create --label app=policy --label onap=1 --driver bridge onap-policy

  echo -e "\nCreating volumes..."
  docker volume create --label app=policy --label onap=1 --driver local policy-data

  ## policy-dbhost
  echo -e "\nLaunching policy-mariadb..."
  docker run -d --name policy-mariadb \
    --label onap=1 \
    --label app=policy \
    --net onap-policy \
    --network-alias mariadb \
    -p 3306 \
    -v policy-data:/var/lib/mysql \
    dtr.att.dckr.org/onap/policy-db:1.0-STAGING-latest \
      /bin/bash -c 'exec bash /tmp/do-start.sh'

  ## nexus
  echo -e "\nLaunching nexus..."
  docker run -d --name nexus \
    --label onap=1 \
    --label app=policy \
    --net onap-policy \
    -p 8081 \
    dtr.att.dckr.org/onap/policy-nexus:1.0-STAGING-latest \
      /bin/bash -c '/opt/nexus/nexus-2.14.2-01/bin/nexus start && wait'

  ## drools
  echo -e "\nLaunching drools..."
  docker run -d --name drools \
    --label onap=1 \
    --label app=policy \
    --net onap-policy \
    -p 6969 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/policy/drools/settings.xml:/usr/share/maven/conf/settings.xml \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/policy/opt/policy/config/drools:/tmp/policy-install/config \
    dtr.att.dckr.org/onap/policy-drools:1.0-STAGING-latest \
      /bin/bash -c './do-start.sh'

  ## pap
  echo -e "\nLaunching pap..."
  docker run -d --name pap \
    --label onap=1 \
    --label app=policy \
    --net onap-policy \
    -p 8443 \
    -p 9091 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/policy/opt/policy/config/pe:/tmp/policy-install/config \
    dtr.att.dckr.org/onap/policy-pe:1.0-STAGING-latest \
      /bin/bash ./do-start.sh pap

  ## pdp
  echo -e "\nLaunching pdp..."
  docker run -d --name pdp \
    --label onap=1 \
    --label app=policy \
    --net onap-policy \
    -p 8081 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/policy/opt/policy/config/pe:/tmp/policy-install/config \
    dtr.att.dckr.org/onap/policy-pe:1.0-STAGING-latest \
      /bin/bash ./do-start.sh pdp

  ## pypdp
  echo -e "\nLaunching pypdp..."
  docker run -d --name pypdp \
    --label onap=1 \
    --label app=policy \
    --net onap-policy \
    -p 8480 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/policy/opt/policy/config/pe:/tmp/policy-install/config \
    dtr.att.dckr.org/onap/policy-pe:1.0-STAGING-latest \
      /bin/bash ./do-start.sh pypdp

  ## brmsgw
  echo -e "\nLaunching brmsgw..."
  docker run -d --name brmsgw \
    --label onap=1 \
    --label app=policy \
    --net onap-policy \
    -p 9989 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/policy/opt/policy/config/pe:/tmp/policy-install/config \
    dtr.att.dckr.org/onap/policy-pe:1.0-STAGING-latest \
      /bin/bash ./do-start.sh brmsgw
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
