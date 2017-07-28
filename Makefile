include config
# some common constants
OPENRESTY_HOME := /usr/local/openresty
EXIST_HOME := /usr/local/eXist
EXIST_DATA_DIR := webapp/WEB-INF/data
EXIST_LOGS_DIR := webapp/WEB-INF/logs
# Derived
OS_NAME      :=  $(shell cat /etc/*release | grep -oP '^NAME="\K\w+')
SYSTEMD_PATH := $(if $(shell id -u | grep -oP '^0$$'),\
$(dir $(shell pgrep -fau $$(whoami) systemd | head -n 1 | cut -d ' ' -f 2))system,)

# ifeq ($(wildcard $(SYSTEMD_PATH) ),)
#  $(error 'could not establish systemd path')
# endif

#this will evaluate when running as sudo
# otherwise will be empty when running on remote
# so if running as sudo on desktop we can change permissions back to $SUDO_USER
#$(if $(SUDO_USER),$(info do something),$(info do not do anything))
SUDO_USER := $(shell echo "$${SUDO_USER}")
WHOAMI    := $(shell whoami)
INSTALLER := $(if $(SUDO_USER),$(SUDO_USER),$(WHOAMI))

ifeq ($(SUDO_USER),)
  GIT_USER :=  $(shell git config --get user.name )
  GIT_EMAIL := $(shell git config --get user.email)
else
  GIT_USER=$(shell su -c "git config --get user.name" $(INSTALLER) )
  GIT_EMAIL := $(shell su -c "git config --get user.email" $(INSTALLER) )
endif

ifeq ($(INSTALLER),travis)
 TRAVIS := $(INSTALLER)
else
 TRAVIS =
endif

comma := ,
empty :=
space := $(empty) $(empty)
delimit := $(comma)$(empty)
colon := :
$(colon) := :

# this is used in the certBot ini 
# We want to use SNI
MY_DOMAINS := $(subst $(space),$(comma)$(empty) $(empty),$(DOMAINS))

# ifeq ( $(shell id -u | grep -oP '^0$$')),0)
# GIT_USER=$(shell su -c "git config --get user.name" gmack )
# endif
# GIT_USER=$(shell su -c "git config --get user.name" gmack )
# echo 'spawn su -c " id -u | grep -oP '^0$$'" -s /bin/sh $(INSTALLER)' >> $(@),\
# export PATH := $(abspath bin):$(PATH)
export PATH := /sbin:$(PATH)

T := tmp
ifeq ($(wildcard $(T)),)
 $(shell  mkdir $(T))
endif

# Make sure we have the following apps installed:
APP_LIST := wget curl nmap
assert-command-present = $(if $(shell which $1),,$(error '$1' missing and needed for this build))

$(foreach src,$(APP_LIST),$(call assert-command-present,$(src)))

assert-file-present = $(if $(wildcard $1),,$(error '$1' missing and needed for this build))

assert-is-root = $(if $(shell id -u | grep -oP '^0$$'),,\
 $(error changing system files so need to sudo) )
# assert-is-root = $(if $(shell id -u | grep -oP '^0$$'),\
#  $(info OK! root user, so we can change some system files),\
#  $(error changing system files so need to sudo) )

cat = $(shell if [ -e $(1) ] ;then echo "$$(<$(1))";fi )

chownToUser = $(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $1,)

#this will evaluate if we have a access token
ACCESS_TOKEN := $(call cat,$(ACCESS_TOKEN_PATH))

# GIT_REMOTE_ORIGIN_URl="$(shell git config --get remote.origin.url )"
# GIT_REPO_FULL_NAME="$(shell echo $(GIT_REMOTE_ORIGIN_URl) | sed -e 's/git@github.com://g' | sed -e 's/\.git//g' )"
# GIT_REPO_NAME="$(shell echo $(GIT_REPO_FULL_NAME) |cut -d/ -f2 )"
# GIT_REPO_OWNER_LOGIN="$(shell echo $(GIT_REPO_FULL_NAME) |cut -d/ -f1 )"

# $(info git user name established)
#  $(info git user email established)
$(if $(GIT_USER),,$(error no git user name ))
$(if $(GIT_EMAIL),,$(error no git user email ))

# if we have a github access token use that as admin pass
# $(if $(ACCESS_TOKEN),\
#  $(info using found 'access token' for password),\
#  $(info using 'admin' for password ))

P := $(if $(ACCESS_TOKEN),$(ACCESS_TOKEN),admin)

.SECONDARY:

include mk-includes/*

default: help

help:
	@echo 'OS NAME: $(OS_NAME) '
	@echo 'SYSTEMD_PATH: $(SYSTEMD_PATH) '
	@echo 'SUDO_USER : $(SUDO_USER)'
	@echo 'WHOAMI    $(WHOAMI)'
	@echo 'INSTALLER : $(INSTALLER)'
	@echo 'GIT_USER : $(GIT_USER)'
	@echo 'GIT_EMAIL: $(GIT_EMAIL)'
	@echo 'DOMAIN: $(DOMAIN)'
	@echo 'DOMAINS: $(DOMAINS)'
	@echo 'MY_DOMAINS: $(MY_DOMAINS)'
	@echo '-----------------------------'
	@echo '-----    NOTES          -----'
	@echo '-----------------------------'
	@echo 'make help-tls-certs'
	@echo 'make help-eXist-install'
	@echo 'make help-eXist-service'

help-OpenResty-install:
	@cat notes/openresty-install.md | head -n 10

help-eXist-install:
	@cat notes/eXist-install.md | head -n 10

help-eXist-service:
	@cat notes/eXist-service.md | head -n 26

help-tls-certs:
	@cat notes/tls-certs.md | head -n 18

###############################################

build: exInstall

#orInstall






