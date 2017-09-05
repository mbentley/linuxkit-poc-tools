linuxkit-poc-tools
==================

* `populate_images.sh` - used to pull images from random sources and push them to a DTR for centralized storage
* `onaplaunch/` - contains scripts to launch ONAP via `docker run` commands; see the `_all.sh` script for standing up the whole stack (needs a box with at least 32 GB of RAM to start; more if you want to run anything more complex or leave it running for more than a short amount of time).  There is also a [Dockerfile](onaplaunch/Dockerfile.launch) that will build an image that will deploy ONAP.  See the [README](./onaplaunch/README.md) for more details
* `oomclone/` - contains a Dockerfile used to build an image that will clone the oom repo which contains the supporting files
* `onap.yml` - contains a LinuxKit definition file that will create an ONAP deployable VM
* `onap-aws.yml` - similar to `onap.yml` but adds the necessary metadata support for AWS

## Build, push and run in AWS

``` bash
$ export AWS_ACCESS_KEY_ID="<insert key id here>" AWS_SECRET_ACCESS_KEY="<insert access key here>" REGION="<insert region here>"
$ make build-raw
$ make push-aws
$ make run-aws
```

**Note**: It may take some time after you execute `push-aws` before the AMI is actually created so you may want to check.

This assumes you have all of the necessary AWS environment variables set already (see http://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html)
