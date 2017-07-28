.PHONY: all help build run kill rm clean
PROJECT ?= onap
PID = `cat $(PROJECT)-state/hyperkit.pid`

all: help

help:   ## Show this help
	        @fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

build:	## Build the project LinuxKit image
	moby build $(PROJECT).yml

images:	## Build Docker images for ONAP launch and OOM clone
	docker build -f onap/Dockerfile.launch -t dtr.att.dckr.org/services/onaplaunch:latest onap
	docker build -f onap/Dockerfile.oom -t dtr.att.dckr.org/services/oomclone:latest onap

push:	## Push Docker images for ONAP launch and OOM clone to DTR
	docker push dtr.att.dckr.org/services/onaplaunch:latest
	docker push dtr.att.dckr.org/services/oomclone:latest

run:	## Run the project LinuxKit image
	linuxkit run $(PROJECT)

kill:	## Kill the project instance
	kill -9 $(PID)

rm:	## Remove the project state
	rm -rf $(PROJECT)-state

clean:  ## Remove artifacts built for the project
	rm -rf $(PROJECT)-kernel $(PROJECT)-cmdline $(PROJECT)-state $(PROJECT)-*.img $(PROJECT)-*.iso $(PROJECT)-*.gz $(PROJECT)-*.qcow2 $(PROJECT)-*.vhd $(PROJECT)-*.vmx $(PROJECT)-*.vmdk $(PROJECT)-*.tar $(PROJECT)-*.raw
