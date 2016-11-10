
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
#  with eXistdb proxied behind nginx
#  Any Nginx auth will be done using JWT Bearer tokens over HTTPS
#    if Authorised then
#    use Basic Auth to access eXist protected location
#
# @see  https://tools.ietf.org/html/rfc2617
#
# the env var must be set in nginx.conf
# env EXIST_AUTH;
# an then can be accessed use in lua modules
# local existAuth = os.getenv("EXIST_AUTH") 
#
##################################

define openrestyService
[Unit]
Description=OpenResty stack for Nginx HTTP server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
Environment="OPENRESTY_HOME=$(OPENRESTY_HOME)"
Environment="EXIST_AUTH=$(shell echo -n "$(GIT_USER):$(ACCESS_TOKEN)" | base64 )"
WorkingDirectory=$(OPENRESTY_HOME)
PIDFile=$(NGINX_HOME)/logs/nginx.pid
ExecStartPre=$(OPENRESTY_HOME)/bin/openresty -t
ExecStart=$(OPENRESTY_HOME)/bin/openresty -p $(OPENRESTY_HOME)
ExecReload=/bin/kill -s HUP $$MAINPID
ExecStop=/bin/kill -s QUIT $$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
endef

# Environment="LUA_CPATH='/usr/local/openresty/luajit/lib/lua/5.1/?.so;'"
orService: export openrestyService:=$(openrestyService)
orService:
	@echo "setup openresty as nginx.service under systemd"
	@$(call assert-is-root)
	@$(call assert-is-systemd)
	@echo 'Check if service is enabled'
	@echo "$(systemctl is-enabled nginx.service)"
	@echo 'Check if service is active'
	@systemctl is-active nginx.service && systemctl stop  nginx.service || echo 'inactive'
	@echo 'Check if service is failed'
	@systemctl is-failed nginx.service || systemctl stop nginx.service && echo 'inactive'
	@echo "$${openrestyService}" > /dev/null
	@echo "$${openrestyService}" > /lib/systemd/system/nginx.service
	@systemd-analyze verify nginx.service
	@systemctl is-enabled nginx.service || systemctl enable nginx.service
	@systemctl start nginx.service
	@echo 'Check if service is enabled'
	@systemctl is-enabled nginx.service
	@echo 'Check if service is active'
	@systemctl is-active nginx.service
	@echo 'Check if service is failed'
	@systemctl is-failed nginx.service || echo 'OK!'
	@journalctl -f -u nginx.service -o cat
	@echo '--------------------------------------------------------------'

scpAccessToken:
	@echo 'copy current access token over to remote'
	@scp $(ACCESS_TOKEN) $(SERVER):~/$(GIT_USER)
