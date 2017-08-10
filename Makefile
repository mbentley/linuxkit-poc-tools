.PHONY: all help build build-raw images push run kill rm clean
PROJECT ?= onap-aws
PID = `cat $(PROJECT)-state/hyperkit.pid`

all: help

help:   	## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

build:		## Build the project LinuxKit image
	moby build $(PROJECT).yml

build-raw:	## Build the project LinuxKit image (RAW)
	moby build -output raw $(PROJECT).yml

images:		## Build Docker images for ONAP launch and OOM clone
	docker build -f onaplaunch/Dockerfile.launch -t dtr.att.dckr.org/services/onaplaunch:latest onaplaunch
	docker build -f oomclone/Dockerfile.oom -t dtr.att.dckr.org/services/oomclone:latest oomclone

push:		## Push Docker images for ONAP launch and OOM clone to DTR
	docker push dtr.att.dckr.org/services/onaplaunch:latest
	docker push dtr.att.dckr.org/services/oomclone:latest

push-aws:	## Push the raw image to AWS
	linuxkit push aws -bucket mbentley-linuxkit-poc onap-aws.raw

run:		## Run the project LinuxKit image
	linuxkit run $(PROJECT)

run-aws:	## Run the project LinuxKit image on AWS
	linuxkit run aws -disk-type gp2 -disk-size 60 -machine t2.2xlarge -zone a $(PROJECT)

kill:		## Kill the project instance
	kill -9 $(PID)
	rm $(PROJECT)-state/hyperkit.pid

rm:		## Remove the project state
	rm -rf $(PROJECT)-state

clean:  	## Remove artifacts built for the project
	rm -rf $(PROJECT)-kernel $(PROJECT)-cmdline $(PROJECT)-state $(PROJECT)-*.img $(PROJECT)-*.iso $(PROJECT)-*.gz $(PROJECT)-*.qcow2 $(PROJECT)-*.vhd $(PROJECT)-*.vmx $(PROJECT)-*.vmdk $(PROJECT)-*.tar $(PROJECT)-*.raw
