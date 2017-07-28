#MAIN TARGETS
define helpOrInstall
# eXist Install

```
make exInstallDownload
make exInstall
make exClean
```

 - exInstallDownload


- exInstall :
 automated fetch and install of latest eXist version

- exClean : 
 this will stop the eXist service then mv the existing install into the backup dir


endef


.PHONY: exInstall exClean exInstallDownload
############################################

exInstallDownload:
	@rm $(T)/eXist-latest.version 2>/dev/null || echo 'latest versions gone'
	@$(MAKE) --silent $(T)/eXist-latest.version
	@cat $(T)/eXist-latest.version

exInstall: exInstallDownload
exInstall:
	@$(MAKE) --silent $(T)/eXist-run.sh
	@$(MAKE) --silent exMimeTypes

exClean:
	@echo 'stop eXist'
	@$(if $(SUDO_USER),\
 $(MAKE) exServiceStop,\
 sudo $(MAKE) exServiceStop)
	@echo 'removing eXist dir'
	@mkdir /usr/local/backup
	@if [ -e  $(EXIST_HOME) ];then cp -R $(EXIST_HOME) /usr/local/backup/;fi

# dependency chain

$(T)/eXist-latest.version:
	@echo "## $@ ##"
	@mkdir -p $(@D)
	@echo 'fetch the latest eXist version'
	@echo $$( curl -s -L https://bintray.com/existdb/releases/exist/_latestVersion |\
 tr -d '\n\r' |\
 grep -oP 'eXist-db-setup-([0-9]+\.){2}([0-9]+)\.jar' |\
 head -1) > $(@)
	@echo '-----------------------------------------------------'

$(T)/wget-eXist.log:  $(T)/eXist-latest.version
	@echo "## $(notdir $@) ##"
	@echo "$(call cat,$<)"
	echo '# because we use wget with no clobber, if we have source then just touch log'
	@$(if $(wildcard $(T)/$(call cat,$<)),\
 touch $@,\
 wget -o $@ -O "$(T)/$(call cat,$<)" \
 --trust-server-name  -S --show-progress -nc \
 "https://bintray.com/artifact/download/existdb/releases/$(call cat,$<)" )
	@cat $@
	@echo '----------------------------------------------------'

$(T)/eXist.expect: $(T)/wget-eXist.log
	@echo "## $(notdir $@) ##"
	@echo 'Create data dir'
	@echo 'we have $(call cat,$(T)/eXist-latest.version)'
	@echo 'creating expect file'
	@echo '#!$(shell which expect) -f' > $(@)
	$(if $(SUDO_USER),\
 echo 'spawn su -c "java -jar $(T)/$(call cat,$(T)/eXist-latest.version) -console" -s /bin/sh $(INSTALLER)' >> $(@),\
 echo 'spawn java -jar $(T)/$(call cat,$(T)/eXist-latest.version) -console' >> $(@))
	@echo 'expect "Select target" { send "$(EXIST_HOME)\n" }'  >> $(@)
	@echo 'expect "*ress 1" { send "1\n" }'  >> $(@)
	@echo 'expect "*ress 1" { send "1\n" }'  >> $(@)
	@echo 'expect "Data dir" { send "$(EXIST_DATA_DIR)\n" }' >> $(@)
	@echo 'expect "*ress 1" { send "1\n" }' >> $(@)
	@echo 'expect "Enter password" { send "$(P)\n" }' >> $(@)
	@echo 'expect "Enter password" { send "$(P)\n" }' >> $(@)
	@echo 'expect "Maximum memory" { send "\n" }'  >> $(@)
	@echo 'expect "Cache memory" { send "\n" }'  >> $(@)
	@echo 'expect "*ress 1" {send "1\n"}'  >> $(@)
	@echo 'expect -timeout -1 "Console installation done" {' >> $(@)
	@echo ' wait'  >> $(@)
	@echo ' exit'  >> $(@)
	@echo '}'  >> $(@)
	@$(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $(@),)
	@chmod +x $(@)
	@echo '---------------------------------------'

$(T)/eXist-expect.log: $(T)/eXist.expect
	@echo "## $(notdir $@) ##"
	@echo "$(EXIST_HOME)"
	@$(if $(shell curl -I -s -f 'http://localhost:8080/' ),\
 $(error detected eXist already running),)
	@$(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $(EXIST_HOME),)
	@echo "Install eXist via expect script. Be Patient! this can take a few minutes"
	@$(<) | tee $(@)
	@$(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $(@),)
	@echo '---------------------------------------'

$(T)/eXist-run.sh: $(T)/eXist-expect.log
	@echo "## $(notdir $@) ##"
	@echo '#!/usr/bin/env bash' > $(@)
	@echo 'cd $(EXIST_HOME)' >> $(@)
	@echo 'java -Djava.endorsed.dirs=lib/endorsed -jar start.jar jetty &' >> $(@)
	@echo 'while [[ -z "$$(curl -I -s -f 'http://127.0.0.1:8080/')" ]] ; do sleep 10 ; done' >> $(@)
	@chmod +x $(@)
	@$(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $(@),)
	@$(if $(TRAVIS),$(@),)
	@echo '---------------------------------------'
