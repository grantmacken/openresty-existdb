# latest  versions
ifeq ($(wildcard  $(T)/eXist-latest.version),)
  $(shell echo '0.0.0' > $(T)/eXist-latest.version )
endif

# previous versions
ifeq ($(wildcard $(T)/eXist-previous.version),)
  $(shell echo '0.0.0' > $(T)/eXist-previous.version )
endif

exLatest: $(T)/eXist-latest.version

exLatestClean:
	@rm $(T)/eXist*

exVer != [ -e $(T)/eXist-latest.version ] && cat $(T)/eXist-latest.version  || echo  -n ''

$(T)/eXist-latest.version: $(T)/eXist-previous.version 
	@echo " $(notdir $@)"
	@cp -f $@ $(<)
	@echo 'fetch the latest eXist version'
	@echo $$( curl -s -L https://bintray.com/existdb/releases/exist/_latestVersion|\
 tr -d '\n\r' |\
 grep -oP 'eXist-db-setup-[0-9]+\.[0-9]+-[a-z0-9]+.jar' |\
 head -1) > $(@)
	@echo "$(exVer)"
	@touch  $(<)
	@echo '-----------------------------------------------------'

EXIST_DOWNLOAD_SOURCE=https://bintray.com/artifact/download/existdb/releases

$(T)/wget-eXist.log:  $(T)/eXist-latest.version
	@echo "## $(notdir $@) ##"
	echo '# because we use wget with no clobber, if we have source then just touch log'
	@$(if $(wildcard $(T)/$(exVer)),\
 touch $@,\
 wget -o $@ -O "$(T)/$(exVer)" \
 --trust-server-name  --progress=dot$(:)mega -nc \
 "$(EXIST_DOWNLOAD_SOURCE)/$(exVer)" )
	@cat $@
	@echo '----------------------------------------------------'

$(T)/eXist.expect: $(T)/wget-eXist.log
	@echo "## $(notdir $@) ##"
	@echo 'Create data dir'
	@echo 'we have $(call EXIST_JAR)'
	@echo 'creating expect file'
	@echo '#!$(shell which expect) -f' > $(@)
	$(if $(SUDO_USER),\
 echo 'spawn su -c "java -jar $(T)/$(exVer) -console" -s /bin/sh $(INSTALLER)' >> $(@),\
 echo 'spawn java -jar $(T)/$(exVer) -console' >> $(@))
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
	@echo 'remove any exiting eXist instalation'
	@if [ -d $(EXIST_HOME) ] ;then rm -R $(EXIST_HOME) ;fi
	@echo 'make eXist dir and reset permissions back to user'
	@mkdir -p $(EXIST_HOME)
	@$(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $(EXIST_HOME),)
	@echo "Install eXist via expect script. Be Patient! this can take a few minutes"
	@$(<) | tee $(@)
	@$(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $(@),)
	@echo '---------------------------------------'

$(T)/eXist-run.sh: $(T)/eXist-expect.log
	@echo "## $(notdir $@) ##"
	@echo '#!/usr/bin/env bash' > $(@)
	@echo 'cd $(EXIST_HOME)' >> $(@)
	@echo 'java -Djava.endorsed.dirs=lib/endorsed -Djava.net.preferIPv4Stack=true -jar start.jar jetty &' >> $(@)
	@echo 'while [[ -z "$$(curl -I -s -f 'http://127.0.0.1:8080/')" ]] ; do sleep 5 ; done' >> $(@)
	@chmod +x $(@)
	@$(if $(SUDO_USER),chown $(SUDO_USER)$(:)$(SUDO_USER) $(@),)
	@echo '---------------------------------------'

