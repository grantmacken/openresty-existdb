# Set Up OpenResty as a Service
##################################

define openrestyService
[Unit]
Description=OpenResty stack for Nginx HTTP server
After=network.target

[Service]
Type=forking
Environment="OPENRESTY_HOME=$(OPENRESTY_HOME)"
Environment="EXIST_HOME=$(EXIST_HOME)"
Environment="EXIST_DATA_DIR=$(EXIST_DATA_DIR)"
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
	@cat $<
	@systemctl is-enabled openresty.service  || systemctl enable openresty.service
	@echo "Service is: $(call orServiceIs,enabled)"
	@systemctl is-active openresty.service  || systemctl start openresty.service
	@echo "Service is: $(call orServiceIs,active)"
	@echo "Service is: $(call orServiceIs,failed)"
	@systemctl is-failed openresty.service && $(MAKE) --silent orServiceStateDiag || \
 $(MAKE) --silent orServiceState

$(SYSTEMD_PATH)/openresty.service: export openrestyService:=$(openrestyService)
$(SYSTEMD_PATH)/openresty.service:
	@$(call assert-is-root)
	@echo "Setup OpenResty as openresty.service under systemd"
	@echo "$${openrestyService}" > $@

orServiceStateDiag:
	@echo ' ========================================================='
	systemctl status openresty.service
	@echo ' ========================================================='
	journalctl -xe 
	false

orServiceState:
	@sleep 1
	@echo ''
	@echo ' ========================================================='
	@echo ''
	@nmap --reason -sT 127.0.0.1 | grep  open
	@sleep 1
	@echo ''
	@echo ' ========================================================='
	@echo ''
	@echo ''
	@echo "Service is enabled: $(call orServiceIs,enabled)"
	@echo "service is active: $(call orServiceIs,active)"
	@echo "Service is failed: $(call orServiceIs,failed)"
	@echo ''
	@echo ' ========================================================='

orServiceRemove:
	@$(call assert-is-root)
	@$(MAKE) orServiceStop
	@systemctl is-enabled openresty.service >/dev/null && systemctl disable openresty.service
	@[ -e $(SYSTEMD_PATH)/openresty.service ] && rm $(SYSTEMD_PATH)/openresty.service
	@systemctl daemon-reload

orServiceStart:
	@$(call assert-is-root)
	@systemctl is-enabled  openresty.service >/dev/null
	@systemctl is-active openresty.service  >/dev/null \
 && true || systemctl start openresty.service
	@systemctl is-failed openresty.service  >/dev/null \
 && systemctl start openresty.service;wait || true
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
 systemctl stop openresty.service;wait || \
 echo 'already $(call orServiceIs,active)'
	@systemctl daemon-reload
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
	tail $(OPENRESTY_HOME)/nginx/logs/error.log

orLoggedErrorFollow:
	@echo 'openresty home : $(OPENRESTY_HOME)'
	tail -n -1 -f  $(OPENRESTY_HOME)/nginx/logs/error.log
