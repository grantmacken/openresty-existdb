
JAVA := $(shell which java)

START_JAR := $(JAVA) \
 -Dexist.home=$(EXIST_HOME) \
 -Djetty.home=$(EXIST_HOME)/tools/jetty \
 -Dfile.encoding=UTF-8 \
 -Djava.endorsed.dirs=$(EXIST_HOME)/lib/endorsed \
 -jar $(EXIST_HOME)/start.jar


define eXistService
[Unit]
Description=The exist db application server
After=network.target

[Service]
Environment="EXIST_HOME=$(EXIST_HOME)"
$(if $(SUDO_USER),
Environment="SERVER=development",
Environment="SERVER=production")
WorkingDirectory=$(EXIST_HOME)
User=$(INSTALLER)
Group=$(INSTALLER)
ExecStart=$(START_JAR) jetty
ExecStop=$(START_JAR) shutdown -u admin -p $(P)

[Install]
WantedBy=multi-user.target
endef


exSrv:  export eXistService:=$(eXistService)
exSrv: 
	@echo "setup eXist as eXist.service under systemd"
	@$(call assert-is-root)
	@echo 'Check if service is enabled'
	@echo "$(systemctl is-enabled eXist.service)"
	@echo 'Check if service is active'
	@echo "$(systemctl is-enabled eXist.service)"
	@systemctl is-active eXist.service && systemctl stop  eXist.service || echo 'inactive'
	@echo "$${eXistService}"
	@echo "$${eXistService}" >  $(SYSTEMD_PATH)/eXist.service

exStartService:
	@$(call assert-is-root)
	@systemctl is-enabled eXist.service || systemctl enable eXist.service
	@systemctl start eXist.service
	@echo 'Check if service is enabled'
	@systemctl is-enabled eXist.service
	@echo 'Check if service is active'
	@systemctl is-active eXist.service
	@echo 'Check if service is failed'
	@systemctl is-failed eXist.service || echo 'OK!'

orNotActive = $(shell systemctl is-active eXist.service | grep -oP 'inactive|failed')

exRemoveService:
	@$(call assert-is-root)
	@[ -e $(SYSTEMD_PATH)/eXist.service ] && rm $(SYSTEMD_PATH)/eXist.service || echo '' 

exStop:
	@$(call assert-is-root)
	@$(if $(orNotActive),, systemctl stop eXist.service)
	@echo 'eXist service is now' $$(systemctl is-active  eXist.service)

exStart:
	@$(call assert-is-root)
	@$(if $(orNotActive),systemctl start eXist.service, )
	@echo 'eXist service is now' $$(systemctl is-active  eXist.service)

exStatus:
	@systemctl status  eXist.service

exLog:
	@$(call assert-is-root)
	@journalctl -f -u eXist.service -o cat



