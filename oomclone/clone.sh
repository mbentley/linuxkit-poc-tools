#!/bin/sh

if [ -d "/root/git/gerrit.onap.org/oom" ]
then
  echo "Cleaning '/root/git/gerrit.onap.org/oom'..."
  rm -rfv /root/git/gerrit.onap.org/oom
  echo "done.";echo
fi

git clone --depth 1 https://github.com/mbentley/oom.git /root/git/gerrit.onap.org/oom

### add any other config hacks below here

# fix static ip in config
DEFAULT_IFACE=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
DEFAULT_IP="$(ip addr show dev "${DEFAULT_IFACE}" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')"
echo "${DEFAULT_IP}" > "${HOME}"/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config/policy/opt/policy/config/pe/ip_addr.txt
