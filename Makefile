include config
# some common constants
OPENRESTY_HOME := /usr/local/openresty
EXIST_HOME := /usr/local/eXist
EXIST_DATA_DIR := webapp/WEB-INF/data
# Derived
OS_NAME      :=  $(shell cat /etc/*release | grep -oP '^NAME="\K\w+')
SYSTEMD_PATH :=  $(dir $(shell  pgrep -fau $$(whoami) systemd | head -n 1 | cut -d ' ' -f 2))system
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

# Make sure we have the following apps installed:
APP_LIST := wget curl
assert-command-present = $(if $(shell which $1),,$(error '$1' missing and needed for this build))

$(foreach src,$(APP_LIST),$(call assert-command-present,$(src)))

assert-file-present = $(if $(wildcard $1),,$(error '$1' missing and needed for this build))

assert-is-root = $(if $(shell id -u | grep -oP '^0$$'),\
 $(info OK! root user, so we can change some system files),\
 $(error changing system files so need to sudo) )

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

default: help

include mk-includes/ex-* 

help:
	@echo 'Install openresty from source'
	@echo 'OS NAME: $(OS_NAME) '
	@echo 'SYSTEMD_PATH: $(SYSTEMD_PATH) '
	@echo 'SUDO_USER : $(SUDO_USER)'
	@echo 'WHOAMI    $(WHOAMI)'
	@echo 'INSTALLER : $(INSTALLER)'
	@echo 'GIT_USER : $(GIT_USER)'
	@echo 'GIT_EMAIL: $(GIT_EMAIL)'
	@echo 'DOMAINS: $(DOMAINS)'
	@echo 'MY_DOMAINS: $(MY_DOMAINS)'

help-eXist:
	@$(call cat,notes/eXist-setup-notes.md)

# eXistdb setup
###############################################

exInstall: $(T)/eXist-run.sh

exGhUser: ex-git-user-as-eXist-user

exClean: 
	@sudo $(MAKE) exStop
	@rm -R $(EXIST_HOME)


###############################################

# OPENRESTY
or:
	@echo 'check if current versions up to date'
	@$(MAKE) checkLatest
	@echo 'install openresty'
	@$(MAKE) orInstall

#orServ: $(SYSTEMD_PATH)/openresty.service

orPaths: $(HOME)/.config/bash/openresty.sh

orPathsClean:
	@echo 'remove openresty bash script' 
	@rm  $(HOME)/.config/bash/openresty.sh

orClean:
	@echo 'remove openresty'
	@rm -R -f $(OPENRESTY_HOME)
	@ls -al /usr/local



opmGet:
	@echo "install opm packages"
	<@opm get pintsized/lua-resty-http
	@opm get SkyLothar/lua-resty-jwt
	@opm get bungle/lua-resty-reqargs


