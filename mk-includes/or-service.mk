

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
#  with eXistdb proxied behind openresty
#  Any Nginx auth will be done using JWT Bearer tokens over HTTPS
#    if Authorised then
#    use Basic Auth to access eXist protected location
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

# Environment="LUA_CPATH='/usr/local/openresty/luajit/lib/lua/5.1/?.so;'"
# SYSTEMD_PATH=/usr/lib/systemd/system

$(SYSTEMD_PATH)/openresty.service:
	@echo "setup openresty as openresty.service under systemd"
	@$(call assert-is-root)
	@echo 'Check if service is enabled'
	@echo "$(systemctl is-enabled openresty.service)"
	@echo 'Check if service is active'
	@echo "$(systemctl is-enabled openresty.service)"
	@systemctl is-active openresty.service && systemctl stop  openresty.service || echo 'inactive'
	@$(MAKE) orService


orService: export openrestyService:=$(openrestyService)
orService:
	@echo "$${openrestyService}"
	@echo "$${openrestyService}" > $(SYSTEMD_PATH)/openresty.service

# @echo '--------------------------------------------------------------'	
orStartService:
	@systemctl is-enabled openresty.service || systemctl enable openresty.service
	@systemctl start openresty.service
	@echo 'Check if service is enabled'
	@systemctl is-enabled openresty.service
	@echo 'Check if service is active'
	@systemctl is-active openresty.service
	@echo 'Check if service is failed'
	@systemctl is-failed openresty.service || echo 'OK!'
	@journalctl -f -u openresty.service -o cat

orNotActive = $(shell systemctl is-active openresty.service | grep -oP 'inactive|failed')

orRemoveService:
	@$(call assert-is-root)
	@[ -e $(SYSTEMD_PATH)/openresty.service ] && rm $(SYSTEMD_PATH)/openresty.service || echo '' 

orStop:
	@$(if $(orNotActive),, systemctl stop openresty.service)
	@echo 'openresty service is now' $$(systemctl is-active  openresty.service)

orStart:
	@$(if $(orNotActive),systemctl start openresty.service, )
	@echo 'openresty service is now' $$(systemctl is-active  openresty.service)

orStatus:
	@systemctl status  openresty.service


daemonReload:
	@echo 'Check if service is enabled'
	@systemd-analyze verify openresty.service
	@systemctl is-enabled openresty.service && systemctl disable openresty.service || echo 'disabled'
	@systemctl daemon-reload
	@systemctl reset-failed

