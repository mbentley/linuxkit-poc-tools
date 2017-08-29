#!/bin/bash

set -e

USERNAME="${USERNAME:-}"
PASSWORD="${PASSWORD:-}"

check_credentials() {
  if [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]
  then
    echo "Error: Missing USERNAME or PASSWORD env var for DTR authentication"
    exit 1
  fi
}

oom_PATH="${HOME}/git/mbentley/oom"

IMAGES_FROM_REPO="$(find "${oom_PATH}" -name "*.yaml" -exec grep 'image:' {} \; | grep -v oomk8s | grep -v get_param | awk -F "image: " '{print $2}' | sort -u)"

IMAGES="aaidocker/aai-hbase-1.2.3:latest
attos/dmaap:latest
dorowu/ubuntu-desktop-lxde-vnc
mariadb:10
mysql/mysql-server:5.6
nexus3.onap.org:10001/mariadb:10.1.11
nexus3.onap.org:10001/openecomp/admportal-sdnc-image:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/ajsc-aai:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/appc-image:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/dgbuilder-sdnc-image:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/model-loader:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/mso:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/policy/policy-db:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/policy/policy-drools:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/policy/policy-nexus:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/policy/policy-pe:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/portalapps:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/portaldb:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/sdc-backend:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/sdc-cassandra:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/sdc-elasticsearch:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/sdc-frontend:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/sdc-kibana:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/sdnc-image:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/testsuite:1.0-STAGING-latest
nexus3.onap.org:10001/openecomp/vid:1.0-STAGING-latest
wurstmeister/kafka:latest
wurstmeister/zookeeper:latest"

list_images() {
	for IMAGE in ${IMAGES}
	do
	  echo "${IMAGE}"
	done
}

compare_images() {
	echo "Pulling updates for gerrit.onap.org/oom..."
	cd "${HOME}"/git/gerrit.onap.org/oom/
	git pull origin master
	echo -e "done.\n"

	if [ "${IMAGES_FROM_REPO}" == "${IMAGES}" ]
	then
		echo "IMAGE list up to date"
	else
		echo "IMAGE list not up to date with oom repo"
		diff <(echo "${IMAGES_FROM_REPO}") <(echo "${IMAGES}")
	fi
}

pull_images() {
	docker login -u docker -p docker nexus3.onap.org:10001

	for IMAGE in ${IMAGES}
	do
	  docker pull "${IMAGE}"
	done
}

retag_images() {
  for IMAGE in ${IMAGES}
  do
    NEW_IMAGE="dtr.att.dckr.org/onap/$(echo "${IMAGE}" | awk -F '/' '{print $NF}')"
    echo -n "Retagging ${IMAGE} => ${NEW_IMAGE}..."
    docker tag "${IMAGE}" "${NEW_IMAGE}"
    echo -e "done"
  done
}

create_repos() {
  check_credentials

  for IMAGE in ${IMAGES}
  do
    NEW_REPO="$(echo "${IMAGE}" | awk -F '/' '{print $NF}' | awk -F ':' '{print $1}')"
    curl -X POST --header "Content-Type: application/json" --header "Accept: application/json" -u "${USERNAME}":"${PASSWORD}" -d "{
      \"name\": \"${NEW_REPO}\",
      \"shortDescription\": \"${NEW_REPO}\",
      \"longDescription\": \"${NEW_REPO}\",
      \"visibility\": \"public\",
      \"scanOnPush\": true
      }" "https://dtr.att.dckr.org/api/v0/repositories/onap" || true
  done
}

update_repos() {
  check_credentials

  for IMAGE in ${IMAGES}
  do
    NEW_REPO="$(echo "${IMAGE}" | awk -F '/' '{print $NF}' | awk -F ':' '{print $1}')"
    curl -X PATCH --header "Content-Type: application/json" --header "Accept: application/json" -u "${USERNAME}":"${PASSWORD}" -d "{
      \"shortDescription\": \"from ${IMAGE}\",
      \"longDescription\": \"Image was pulled from ${IMAGE}\",
      \"visibility\": \"public\",
      \"scanOnPush\": true
      }" "https://dtr.att.dckr.org/api/v0/repositories/onap/${NEW_REPO}" || true
  done
}

push_images() {
  check_credentials

  for IMAGE in ${IMAGES}
  do
    NEW_IMAGE="dtr.att.dckr.org/onap/$(echo "${IMAGE}" | awk -F '/' '{print $NF}')"
    docker login -u "${USERNAME}" -p "${PASSWORD}" dtr.att.dckr.org
    docker push "${NEW_IMAGE}"
  done
}

case ${1} in
  pull)
    pull_images
    ;;
  list)
    list_images
    ;;
  compare)
    compare_images
    ;;
  retag)
    retag_images
    ;;
  create_repos)
    create_repos
    ;;
  update_repos)
    update_repos
    ;;
  push)
    push_images
    ;;
  *)
    echo "Usage: $0 {pull|list|compare|retag|create_repos|update_repos|push}"
    exit 1
    ;;
esac
