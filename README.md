linuxkit-poc-tools
==================

* `populate_images.sh` - used to pull images from random sources and push them to a DTR for centralized storage
* `onaplaunch/` - contains scripts to launch ONAP via `docker run` commands; see the `_all.sh` script for standing up the whole stack (needs a box with at least 32 GB of RAM to start).  There is also a [Dockerfile](onaplaunch/Dockerfile.launch) that will build an image that will deploy ONAP.
* `oomclone` - contains a Dockerfile used to build an image that will clone the oom repo which contains the supporting files
* `onap.yml` - contains a LinuxKit definition file that will create an ONAP deployable VM
* `onap-aws.yml` - similar to `onap.yml` but adds the necessary metadata support for AWS
