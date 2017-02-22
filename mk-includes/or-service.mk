

##################################
# 
# To set up openresty as a service
#
# `make orService'
#
#  note: openresty now symlinked to usr/local/openresty/bin
#  note: system environment variables
#  OPENRESTY HOME  file path to openresty
#  EXIST_AUTH      basic access authentication for exist admin account-
#  this is a base64 encoded string that can  be used for HTTP Basic Athentication 
#  with openrestydb proxied behind openresty
#  Any Nginx auth will be done using JWT Bearer tokens over HTTPS
#    if Authorised then
#    use Basic Auth to access openresty protected location
#
# @see  https://tools.ietf.org/html/rfc2617
#
# the env var must be set in openresty.conf
# env EXIST_AUTH;
# an then can be accessed use in lua modules
# local existAuth = os.getenv("EXIST_AUTH") 
#syslog.target network.target remote-fs.target nss-lookup.target
##################################

define openrestyService
[Unit]
Description=OpenResty stack for Nginx HTTP server
After=network.target

[Service]
Type=forking
Environment="OPENRESTY_HOME=$(OPENRESTY_HOME)"
Environment="EXIST_AUTH=$(shell echo -n "$(GIT_USER):$(ACCESS_TOKEN)" | base64 )"
WorkingDirectory=$(OPENRESTY_HOME)
PIDFile=$(OPENRESTY_HOME)/nginx/logs/nginx.pid
ExecStartPre=$(OPENRESTY_HOME)/bin/openresty -t
ExecStart=$(OPENRESTY_HOME)/bin/openresty
ExecReload=/bin/kill -s HUP $$MAINPID
ExecStop=/bin/kill -s QUIT $$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
endef

orServiceIs = $(shell systemctl is-$(1) openresty.service )

orService: $(SYSTEMD_PATH)/openresty.service
	@systemctl is-enabled openresty.service || systemctl enable openresty.service
	@systemctl is-active openresty.service ||  systemctl start openresty.service
	@$(MAKE) orServiceState

$(SYSTEMD_PATH)/openresty.service: export openrestyService:=$(openrestyService)
$(SYSTEMD_PATH)/openresty.service:
	@$(call assert-is-root)
	@echo "Setup OpenResty as openresty.service under systemd"
	@echo "$${openrestyService}" > $@

orServiceState:
	@echo ''
	@echo ' ========================================================='
	@echo ''
	@echo "Check if service is enabled: $(call orServiceIs,enabled)"
	@echo "Check if service is active: $(call orServiceIs,active)"
	@echo "Check if service is failed: $(call orServiceIs,failed)"
	@sleep 1
	@echo ''
	@echo ' ========================================================='
	@echo ''
	nmap --reason -p 80 127.0.0.1 
	nmap --reason -p 443 127.0.0.1 
	sleep 1
	@echo ''
	@echo ' ========================================================='
	@echo ''

orServiceRemove:
	@$(call assert-is-root)
	@$(MAKE) orServiceStop
	@systemctl is-enabled openresty.service >/dev/null && systemctl disable openresty.service
	@[ -e $(SYSTEMD_PATH)/openresty.service ] && rm $(SYSTEMD_PATH)/openresty.service
	@systemctl daemon-reload

orServiceStart:
	@$(call assert-is-root)
	@systemctl is-enabled  openresty.service >/dev/null
	@systemctl is-active openresty.service  >/dev/null && true || systemctl start openresty.service
	@systemctl is-failed openresty.service  >/dev/null && systemctl start openresty.service || true
	@$(MAKE) --silent orServiceState
	@$(MAKE) --silent orLoggedErrors

orServiceStartDev:
	@$(call assert-is-root)
	@systemctl is-enabled  openresty.service >/dev/null
	@systemctl is-active openresty.service  >/dev/null && true || systemctl start openresty.service
	@systemctl is-failed openresty.service  >/dev/null && systemctl start openresty.service || true
	@$(MAKE) --silent orServiceState
	@$(MAKE) --silent orLoggedErrorFollow

orServiceStop:
	@$(call assert-is-root)
	@systemctl is-enabled  openresty.service  >/dev/null
	@systemctl is-active openresty.service >/dev/null && \
 systemctl stop openresty.service >/dev/null || \
 echo 'already $(call orServiceIs,active)'
	@$(MAKE) --silent orLoggedErrors
	@$(MAKE) --silent exServiceState

orServiceStatus:
	@systemctl status  openresty.service

orServiceLogFollow:
	@$(call assert-is-root)
	@journalctl -f -u openresty.service -o cat

orServiceLog:
	@$(call assert-is-root)
	@journalctl -u openresty.service -o cat | tail -n 4

orLoggedErrors:
	@echo 'openresty home : $(OPENRESTY_HOME)'
	tail -n 20 $(OPENRESTY_HOME)/nginx/logs/error.log

orLoggedErrorFollow:
	@echo 'openresty home : $(OPENRESTY_HOME)'
	tail -n -1 -f  $(OPENRESTY_HOME)/nginx/logs/error.log

scpAccessToken:
	@echo 'copy current access token over to remote'
	@scp $(ACCESS_TOKEN) $(SERVER):~/$(GIT_USER)
