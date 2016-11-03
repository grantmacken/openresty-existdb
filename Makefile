include config
SHELL=/bin/bash
export PATH := $(abspath bin):$(PATH)
T := .temp
# Make sure we have the following apps installed:
APP_LIST := wget git curl expect stow
assert-command-present = $(if $(shell which $1),,$(error '$1' missing and needed for this build))
$(foreach src,$(APP_LIST),$(call assert-command-present,$(src)))
#
assert-file-present = $(if $(wildcard $1),,$(error '$1' missing and needed for this build))

assert-is-root = $(if $(shell id -u | grep -oP '^0$$'),\
 $(info OK! root user, so we can change some system files),\
 $(error changing system files so need to sudo) )

assert-is-systemd = $(if $(shell ps -p1 | grep systemd),\
 $(info OK! systemd is init system),\
 $(error  init system is not systemd))

cat = $(shell if [ -e $(1) ] ;then echo "$$(<$(1))";fi )

colon := :
$(colon) := :


# REPO  := $(shell  echo '$(DEPLOY)' | cut -d/ -f2 )
# OWNER := $(shell echo $(DEPLOY) |cut -d/ -f1 )
# WEBSITE := $(addprefix http://,$(REPO))
# MAKE_VERSION := $(shell make --version | head -1)
# SYSTEMD := $(shell ps -p1 | grep systemd )
# $(info who am i - $(WHOAMI))
# $(info SUDO USER - $(SUDO_USER))
# $(info make version - $(MAKE_VERSION))
# $(info system - $(SYSTEMD))
# $(info current working directory - $(shell pwd))
# $(info which - $(shell which netstat))
# $(info eXist home - $(EXIST_HOME))
# $(info  travis java  home - $(JAVA_HOME))
# $(info  repo - $(REPO))
# $(info  owner - $(OWNER))
# $(info  website - $(WEBSITE))
# $(info GIT USER - $(GIT_USER))

#this will evaluate when running as sudo
# otherwise will be empty when running on remote
# so if running as sudo on desktop we can change permissions back to $SUDO_USER
#$(if $(SUDO_USER),$(info do something),$(info do not do anything))
SUDO_USER := $(shell echo "$${SUDO_USER}")
WHOAMI    := $(shell whoami)
INSTALLER := $(if $(SUDO_USER),$(SUDO_USER),$(WHOAMI))
# $(info who am i - $(WHOAMI))
# $(info SUDO USER - $(SUDO_USER))

chownToUser = $(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $1,)
#this will evaluate when running on travis
# ifeq ($(INSTALLER),travis)
#  TRAVIS := $(INSTALLER)
# elsr
#  TRAVIS =
# endif
#this will evaluate if we have a access token
ACCESS_TOKEN := $(call cat,$(ACCESS_TOKEN_PATH))
# if we have a github access token use that as admin pass
# $(if $(ACCESS_TOKEN),\
#  $(info using found 'access token' for password),\
#  $(info using 'admin' for password ))
GIT_USER := $(shell git config --get user.name)
# P := $(if $(ACCESS_TOKEN),$(ACCESS_TOKEN),admin)
#AUTH_BASIC := $(shell  echo -n "$(GIT_USER):$(ACCESS_TOKEN)" | base64 )
## SETUP ###
# chownToUser = $(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $1,)
$(if $(wildcard $(T)/),,$(shell mkdir $(T)))
# $(call chownToUser,$(T))
# # $(info website - $(REPO))
# dnsByPass := $(shell echo "$$( cat /etc/hosts | grep $(REPO))")
# $(info dns by pass - $(dnsByPass))

# $(if $(dnsByPass),\
#  $(info dns bypass for $(REPO) has been setup),\
#  $(shell echo "127.0.0.1  $(REPO)" >> /etc/hosts))

# PROVE := $(shell which prove)

default: help

include includes/*

.PHONY: help prep 

help:
	@cat README.md

info:
	@echo "$(GIT_USER)"
	@echo "$(AUTH_BASIC)"

prep:
	@echo 'use the prep script to install dependencies'
	@$(call assert-is-root)
	@[ -x  bin/prep ] || chmod +x bin/prep
	@prep

eXist: $(T)/eXist-run.sh

# shortcut aliases
# create diffie
ngDH: openresty/nginx/ssl/dh-param.pem
# port 80 only
# @sudo rm $(NGINX_HOME)/logs/access.log
# @[ -e openresty/nginx/conf/dev.conf ] && rm openresty/nginx/conf/dev.conf || echo 'first run' 
# @$(MAKE) openresty/nginx/conf/dev.conf
# @$(MAKE) stow
# @sudo systemctl stop nginx.service
# @sudo $(NGINX_HOME)/sbin/nginx -t -c conf/dev.conf
# @sudo systemctl start nginx.service

crl:
	w3m http://$(DOMAIN)

seige:
	@curl -L http://$(DOMAIN)
	@curl -I https://$(DOMAIN)
	@siege -c 15 -r 10 https://$(DOMAIN)

check2:
	@openssl s_client -connect $(DOMAIN):443 -status
# @cat $(NGINX_HOME)/logs/access.log | awk '{print $4}' 
# | awk -F : '{print $2 ":" $3}' | uniq -c

monitor:
	@echo '$(NGINX_HOME)/logs/access.log'
	@ngxtop -v  -l $(NGINX_HOME)/logs/access.log -f combined
