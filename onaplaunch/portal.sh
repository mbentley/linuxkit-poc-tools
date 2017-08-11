#!/bin/bash

set -e

# figure out host ip
DEFAULT_IFACE=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
DEFAULT_IP="$(ip addr show dev "${DEFAULT_IFACE}" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')"

remove() {
  echo -e "\nKilling and removing containers..."
  #shellcheck disable=2046
  docker kill $(docker ps -f label=app=portal -qa) || true
  #shellcheck disable=2046
  docker rm $(docker ps -f label=app=portal -qa) || true

  echo -e "\nRemoving volumes..."
  #shellcheck disable=2046
  docker volume rm $(docker volume ls -f label=app=portal -q) || true

  echo -e "\nRemoving networks..."
  #shellcheck disable=2046
  docker network rm $(docker network ls -f label=app=portal -q) || true
}

launch() {
  # portal
  echo -e "\nCreating network..."
  docker network create --label app=portal --label onap=1 --driver bridge onap-portal

  echo -e "\nCreating volumes..."
  docker volume create --label app=portal --label onap=1 --driver local portal-mariadb-data
  docker volume create --label app=portal --label onap=1 --driver local portal-ubuntu-init
  docker volume create --label app=portal --label onap=1 --driver local portalapps-logs

  ## portaldb
  echo -e "\nLaunching portaldb..."
  docker run -d --name portaldb \
    --label onap=1 \
    --label app=portal \
    --net onap-portal \
    -p 3306 \
    -e MYSQL_HOST=portaldb.onap-portal \
    -e MYSQL_ROOT_PASSWORD=password \
    -v portal-mariadb-data:/var/lib/mysql \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/mariadb/Apps_Users_OnBoarding_Script.sql:/docker-entrypoint-initdb.d/z_Apps_Users_OnBoarding_Script.sql \
    dtr.att.dckr.org/onap/portaldb:1.0-STAGING-latest

  ## portalapps
  echo -e "\nLaunching portalapps..."
  docker run -d --name portalapps \
    --label onap=1 \
    --label app=portal \
    --net onap-portal \
    -p 30213:8005 \
    -p 30214:8009 \
    -p 8989:8080 \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPPORTALAPP/fusion.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPPORTALAPP/WEB-INF/fusion/conf/fusion.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPPORTALAPP/openid-connect.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPPORTALAPP/WEB-INF/classes/openid-connect.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPPORTALAPP/system.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPPORTALAPP/WEB-INF/conf/system.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPPORTALAPP/portal.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPPORTALAPP/WEB-INF/classes/portal.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPDBCAPP/fusion.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPDBCAPP/WEB-INF/fusion/fusion.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPDBCAPP/system.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPDBCAPP/WEB-INF/conf/system.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPDBCAPP/portal.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPDBCAPP/WEB-INF/classes/portal.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPDBCAPP/dbcapp.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPDBCAPP/WEB-INF/dbcapp/dbcapp.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPSDKAPP/system.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPSDKAPP/WEB-INF/conf/system.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal/portal-fe/webapps/etc/ECOMPSDKAPP/portal.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPSDKAPP/WEB-INF/classes/portal.properties \
    -v "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/portal:/portal_root \
    -v portalapps-logs:/opt/apache-tomcat-8.0.37/logs \
    dtr.att.dckr.org/onap/portalapps:1.0-STAGING-latest

  echo "Yet another hack to wait for portalapps to come up..."
  sleep 15

  ## vnc-portal
  echo -e "\nLaunching vnc-portal..."
  docker run -d --name vnc-portal \
    --label onap=1 \
    --label app=portal \
    --net onap-portal \
    --privileged \
    --add-host sdc.api.simpledemo.openecomp.org:"${DEFAULT_IP}" \
    --add-host portal.api.simpledemo.openecomp.org:"${DEFAULT_IP}" \
    --add-host policy.api.simpledemo.openecomp.org:"${DEFAULT_IP}" \
    --add-host sdc.ui.simpledemo.openecomp.org:"${DEFAULT_IP}" \
    --add-host vid.api.simpledemo.openecomp.org:"${DEFAULT_IP}" \
    -e VNC_PASSWORD=password \
    -v portal-ubuntu-init:/ubuntu-init \
    dtr.att.dckr.org/onap/ubuntu-desktop-lxde-vnc:latest
  # the portal-vnc-dep.yaml file uses some bad hacks to override DNS for some reason; no clue why but holding this here in case i have to implement something like it
  # echo `host sdc-be.onap-sdc | awk ''{print$4}''` sdc.api.simpledemo.openecomp.org  >> /ubuntu-init/hosts; echo `host portalapps.onap-portal | awk ''{print$4}''` portal.api.simpledemo.openecomp.org  >> /ubuntu-init/hosts; echo `host pap.onap-policy | awk ''{print$4}''` policy.api.simpledemo.openecomp.org  >> /ubuntu-init/hosts; echo `host sdc-fe.onap-sdc | awk ''{print$4}''` sdc.ui.simpledemo.openecomp.org  >> /ubuntu-init/hosts; echo `host vid-server.onap-vid | awk ''{print$4}''` vid.api.simpledemo.openecomp.org >> /ubuntu-init/hosts
  # cat /ubuntu-init/hosts >> /etc/hosts
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
