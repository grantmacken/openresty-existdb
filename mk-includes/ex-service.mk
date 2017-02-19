
JAVA := $(shell which java)

START_JAR := $(JAVA) \
 -Dexist.home=$(EXIST_HOME) \
 -Djetty.home=$(EXIST_HOME)/tools/jetty \
 -Dfile.encoding=UTF-8 \
 -Djava.endorsed.dirs=$(EXIST_HOME)/lib/endorsed \
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

exServiceIs = $(shell systemctl is-$(1) eXist.service )

exService: $(SYSTEMD_PATH)/eXist.service
	@systemctl is-enabled eXist.service || systemctl enable eXist.service
	@systemctl is-active eXist.service ||  systemctl start eXist.service
	@for i in $$(seq 1 60);\
 do journalctl -u eXist.service -o cat | tail -n -1  ;\
  sleep 1 ;\
  journalctl -u eXist.service -o cat | tail -n -1  | grep 'Jetty server starting' &>/dev/null && break ;\
 done
	@for i in $$(seq 1 60);\
 do journalctl -u eXist.service -o cat | tail -n -1  ;\
  sleep 1 ;\
  journalctl -u eXist.service -o cat | tail -n 8 | grep 'Server has started,' &>/dev/null && break ;\
 done
	@$(MAKE) exServiceState

$(SYSTEMD_PATH)/eXist.service: export eXistService:=$(eXistService)
$(SYSTEMD_PATH)/eXist.service:
	@$(call assert-is-root)
	@echo "setup eXist as eXist.service under systemd"
	echo "$(SYSTEMD_PATH)/eXist.service"
	@echo "$${eXistService}" > $@

exServiceState:
	@echo "Check if service is enabled: $(call exServiceIs,enabled)"
	@echo "Check if service is active: $(call exServiceIs,active)"
	@echo "Check if service is failed: $(call exServiceIs,failed)"
	@sleep 1
	@echo ''
	@echo ' ========================================================='
	@echo ''
	nmap --reason -p 8080 127.0.0.1 
	sleep 1
	@echo ''
	@echo ' ========================================================='
	@echo ''
	@$(MAKE) exServiceLog

exServiceRemove:
	@$(call assert-is-root)
	@$(MAKE) exServiceStop
	@systemctl is-enabled eXist.service >/dev/null && systemctl disable eXist.service
	@[ -e $(SYSTEMD_PATH)/eXist.service ] && rm $(SYSTEMD_PATH)/eXist.service
	@systemctl daemon-reload

exServiceStop:
	@$(call assert-is-root)
	@systemctl is-enabled  eXist.service  >/dev/null
	@systemctl is-active eXist.service >/dev/null && systemctl stop eXist.service >/dev/null
	@for i in $$(seq 1 60);\
 do journalctl -u eXist.service -o cat | tail -n -1  ;\
  sleep 5 ;\
  journalctl -u eXist.service -o cat | tail -n -1  | grep 'eXist.service failed' &>/dev/null && break ;\
 done
	@$(MAKE) exServiceState

exServiceStart:
	@$(call assert-is-root)
	@systemctl is-enabled  eXist.service
	@systemctl is-failed eXist.service >/dev/null  && systemctl start eXist.service  >/dev/null
	@for i in $$(seq 1 60);\
 do journalctl -u eXist.service -o cat | tail -n -1  ;\
  sleep 1 ;\
  journalctl -u eXist.service -o cat | tail -n -1  | grep 'Jetty server starting' &>/dev/null && break ;\
 done
	@for i in $$(seq 1 60);\
 do journalctl -u eXist.service -o cat | tail -n -1  ;\
  sleep 1 ;\
  journalctl -u eXist.service -o cat | tail -n 8 | grep 'Server has started,' &>/dev/null && break ;\
 done
	@$(MAKE) exServiceState


exStatus:
	@systemctl status  eXist.service

exServiceLog:
	@$(call assert-is-root)
	@journalctl -u eXist.service -o cat | tail -n 8

exLogFollow:
	@$(call assert-is-root)
	@journalctl -f -u eXist.service -o cat

exLogXmldb:
	@tail /usr/local/eXist/webapp/WEB-INF/logs/xmldb.log

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
