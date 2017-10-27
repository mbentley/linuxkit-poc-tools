#!/bin/bash

set -e

# initialize
# shellcheck disable=SC1090
. "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/init.sh"

# figure out host ip where all frontend apps are running
#DEFAULT_IFACE=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
#DEFAULT_IP="$(ip addr show dev "${DEFAULT_IFACE}" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')"
DEFAULT_IP="$(docker run -it --rm -e constraint:frontend==true --net=host busybox ip addr show dev eth0 | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')"

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
  docker network create --label app=portal --label onap=1 --driver overlay --attachable onap-portal

  echo -e "\nCreating volumes..."
  #shellcheck disable=2086
  docker volume create --label app=portal --label onap=1 --driver local ${LOCAL_VOLUME_OPTS}/portal-mariadb-data portal-mariadb-data
  #shellcheck disable=2086
  docker volume create --label app=portal --label onap=1 --driver local ${LOCAL_VOLUME_OPTS}/portal-ubuntu-init portal-ubuntu-init
  #shellcheck disable=2086
  docker volume create --label app=portal --label onap=1 --driver local ${LOCAL_VOLUME_OPTS}/portalapps-logs portalapps-logs

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
    -v "${CONFIG_HOME}"/portal/mariadb/Apps_Users_OnBoarding_Script.sql:/docker-entrypoint-initdb.d/z_Apps_Users_OnBoarding_Script.sql \
    linuxkitpoc/portaldb:1.0-STAGING-latest

  ## portalapps
  echo -e "\nLaunching portalapps..."
  docker run -d --name portalapps \
    --label onap=1 \
    --label app=portal \
    --net onap-portal \
    -p 30213:8005 \
    -p 30214:8009 \
    -p 8989:8080 \
    -e constraint:frontend==true \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPPORTALAPP/fusion.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPPORTALAPP/WEB-INF/fusion/conf/fusion.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPPORTALAPP/openid-connect.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPPORTALAPP/WEB-INF/classes/openid-connect.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPPORTALAPP/system.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPPORTALAPP/WEB-INF/conf/system.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPPORTALAPP/portal.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPPORTALAPP/WEB-INF/classes/portal.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPDBCAPP/fusion.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPDBCAPP/WEB-INF/fusion/fusion.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPDBCAPP/system.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPDBCAPP/WEB-INF/conf/system.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPDBCAPP/portal.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPDBCAPP/WEB-INF/classes/portal.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPDBCAPP/dbcapp.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPDBCAPP/WEB-INF/dbcapp/dbcapp.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPSDKAPP/system.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPSDKAPP/WEB-INF/conf/system.properties \
    -v "${CONFIG_HOME}"/portal/portal-fe/webapps/etc/ECOMPSDKAPP/portal.properties:/PROJECT/APPS/ECOMPPORTAL/ECOMPSDKAPP/WEB-INF/classes/portal.properties \
    -v "${CONFIG_HOME}"/portal:/portal_root \
    -v portalapps-logs:/opt/apache-tomcat-8.0.37/logs \
    linuxkitpoc/portalapps:1.0-STAGING-latest

  echo "Wait for portalapps to come up..."
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
    linuxkitpoc/ubuntu-desktop-lxde-vnc:latest
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
