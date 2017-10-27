#!/bin/bash

# set CONFIG_HOME
export CONFIG_HOME="${CONFIG_HOME:-/data/git/gerrit.onap.org/oom/kubernetes/config/docker/init/src/config}"

# if NFS_HOST passed; use it.  otherwise, detect current host
export NFS_HOST="${NFS_HOST:-}"
if [ -z "${NFS_HOST}" ]
then
  # NFS_HOST not set; figure out the default network interface's IP and use that
  DEFAULT_IFACE=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
  export NFS_HOST
  NFS_HOST="$(ip addr show dev "${DEFAULT_IFACE}" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')"
fi

# export LOCAL_VOLUME_OPTS based off of discovered info
export LOCAL_VOLUME_OPTS="--opt type=nfs --opt o=addr=${NFS_HOST},rw,hard,intr,sync,actimeo=0,nolock --opt device=:/shared_data"
