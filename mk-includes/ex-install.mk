#MAIN TARGETS
define hEXist
# eXist Install

Install eXist on
OPERATING SYSTEM: $(OS_NAME)
INSTALLER:  $(INSTALLER)
SYSTEMD_PATH: $(SYSTEMD_PATH)
EXIT_HOME: $(EXIST_HOME)

make targets

- exBuild: clones git repo and builds eXist in directory $(EXIST_HOME)
- exInit:  starts eXist and resets admin password to my github-access-token
- exPass   set new admin account based on git username and github-access-token

endef

exHelp: export hEXist:=$(hEXist)
exHelp:
	echo "$${hEXist}"

.PHONY: exInstall exClean exInstallDownload
############################################

exInstallDownload:
	@rm $(T)/eXist-latest.version 2>/dev/null || echo 'latest versions gone'
	@rm $(T)/eXist.expect 2>/dev/null || echo 'expect file gone'
	@$(MAKE) --silent $(T)/eXist-latest.version
	@cat $(T)/eXist-latest.version

exInstall: exInstallDownload
exInstall:
	@$(MAKE) --silent $(T)/wget-eXist.log
	@$(MAKE) --silent $(T)/wget-eXist.log

#  this initializes the repo 
$(EXIST_HOME)/.git/HEAD:
	@echo "##  $@ ##"
	@cd /usr/local && git clone git@github.com:eXist-db/exist.git eXist
	@cd $(EXIST_HOME) && git checkout master

# after repo cloned build
# this will generate VERSION.txt
$(EXIST_HOME)/VERSION.txt: $(EXIST_HOME)/build.sh $(EXIST_HOME)/.git/HEAD
	@echo '# $(notdir $@) #'
	@chmod +x $<
	@cd $(EXIST_HOME) && ls -al $(notdir $<)
	@cd $(EXIST_HOME) &&  ./$(notdir $<)
	@touch $(EXIST_HOME)/build.sh

# if the pull touches VERSION.txt
exBuild: $(EXIST_HOME)/VERSION.txt
	@echo '# $(notdir $@) #'
	@cd $(EXIST_HOME) && git pull
	@$(MAKE) exMimeTypes


exExpect:
	@$(MAKE) --silent $(T)/eXist-expect.log

xxx:
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
	@echo 'we have $(shell cat tmp/eXist-latest.version)'
	@echo 'creating expect file'
	@echo '#!$(shell which expect) -f' > $(@)
	@echo exit
	echo 'spawn java -jar $(T)/$(shell cat tmp/eXist-latest.version) -console' >> $(@)
	@echo 'expect "Select target path" { send "$(EXIST_HOME)\n" }'  >> $(@)
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
	@chmod +x $(@)
	@echo '---------------------------------------'

$(T)/eXist-expect.log: $(T)/eXist.expect
	@echo "## $(notdir $@) ##"
	@echo "$(EXIST_HOME)"
	@$(if $(shell curl -I -s -f 'http://localhost:8080/' ),\
 $(error detected eXist already running),)
	@echo "Install eXist via expect script. Be Patient! this can take a few minutes"
	@$(<) | tee $(@)
	@echo '---------------------------------------'


exInitRun: $(T)/eXist-run.sh
	@echo "## $(notdir $@) ##"
	@if [[ -z "$$(curl -I -s -f 'http://127.0.0.1:8080/')" ]] ; then $(<) ; fi
	@if [[ -n "$$(curl -I -s -f 'http://127.0.0.1:8080/')" ]] ; then \
  cd $(EXIST_HOME) && $(shell which java) \
  -jar $(EXIST_HOME)/start.jar client \
  -q \
  -u admin \
  -P '' \
  -x 'sm:passwd("admin","$(ACCESS_TOKEN)")'  |  tail -n -1 ; \
 fi

exPass: $(T)/eXist-run.sh
	@echo "## $(notdir $@) ##"
	@if [[ -z "$$(curl -I -s -f 'http://127.0.0.1:8080/')" ]] ; then $(<) ; fi
	@if [[ -n "$$(curl -I -s -f 'http://127.0.0.1:8080/')" ]] ; then $(MAKE) exGitUserAdd; fi

$(T)/eXist-run.sh:
	@echo "## $(notdir $@) ##"
	@echo '#!/usr/bin/env bash' > $(@)
	@echo 'cd $(EXIST_HOME)' >> $(@)
	@echo 'java -Djava.endorsed.dirs=lib/endorsed -jar start.jar jetty &' >> $(@)
	@echo 'while [[ -z "$$(curl -I -s -f 'http://127.0.0.1:8080/')" ]] ; do sleep 10 ; done' >> $(@)
	@chmod +x $(@)
	@echo '---------------------------------------'
