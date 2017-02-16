
JAVA := $(shell which java)

START_JAR := $(JAVA) \
 -Dexist.home=$(EXIST_HOME) \
 -Djetty.home=$(EXIST_HOME)/tools/jetty \
 -Dfile.encoding=UTF-8 \
 -Djava.endorsed.dirs=$(EXIST_HOME)/lib/endorsed \
 -Djava.log4j.configurationFile=$(EXIST_HOME)/tools/yajsw/conf/log4j2.xml \
 -Djava.awt.headless=true \
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
	@$(call assert-is-root)
	@echo "setup eXist as eXist.service under systemd"
	echo "$(SYSTEMD_PATH)/eXist.service"
	@echo "$${eXistService}"
	@echo "$${eXistService}" > $(SYSTEMD_PATH)/eXist.service
	@$(MAKE) exStartService

exState:
	@echo "Check if service is enabled: $$(systemctl is-enabled eXist.service)"
	@echo "Check if service is active: $$(systemctl is-active eXist.service)"
	@echo "Check if service is failed: $$(systemctl is-failed eXist.service)"
# @systemctl is-active eXist.service && systemctl stop  eXist.service || echo 'inactive'

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

exNotActive = $(shell echo "$$(systemctl is-active eXist.service | grep -oP 'inactive|failed')")

exRemoveService:
	@$(call assert-is-root)
	@$(MAKE) exStop
	@systemctl is-enabled eXist.service && systemctl disable eXist.service
	@[ -e $(SYSTEMD_PATH)/eXist.service ] && rm $(SYSTEMD_PATH)/eXist.service || echo '' 

exStop:
	@$(call assert-is-root)
	@$(if $(exNotActive),, systemctl stop eXist.service)
	@echo 'eXist service is now' $$(systemctl is-active  eXist.service)

exStart:
	@$(call assert-is-root)
	@$(if $(exNotActive),systemctl start eXist.service, )
	@echo 'eXist service is now' $$(systemctl is-active  eXist.service)

exStatus:
	@systemctl status  eXist.service

exLog:
	@$(call assert-is-root)
	@journalctl -u eXist.service -o cat

exLogFollow:
	@$(call assert-is-root)
	@journalctl -f -u eXist.service -o cat

exLogXmldb:
	@tail -n 10 /usr/local/eXist/webapp/WEB-INF/logs/xmldb.log

exLogXmldbClear:
	@echo '' > /usr/local/eXist/webapp/WEB-INF/logs/xmldb.log

exLogExist:
	@ls /usr/local/eXist/webapp/WEB-INF/logs
	@tail -n 10 /usr/local/eXist/webapp/WEB-INF/logs/exist.log

exLogStats:
	@tail -n 10 /usr/local/eXist/webapp/WEB-INF/logs/statistics.log

exLogRestxq:
	@tail -n 10 /usr/local/eXist/webapp/WEB-INF/logs/restxq.log

exLogXmlrpc:
	@tail -n 10 /usr/local/eXist/webapp/WEB-INF/logs/xmlrpc.log
