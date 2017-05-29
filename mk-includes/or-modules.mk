define orModulesHelp
=========================================================
MODULES : working with lua modules  - lua

    < src modules
     [ proccess ] compile check if the compile fails it will throw an error
     [ build ]    move modules into  build dir
     [ upload ]   store modules into eXist dev server
     [ test ]     run unit tests
     [ check ]    with prove run functional tests
==========================================================

`make orModules`
`make watch-orModules`
`make orModules-help`
`make orLoggedErrorFollow`

 1. orModules 
 2. watch-orModules  ...  watch the directory
  'make orModules' will now be triggered by changes in dir
 3. orLoggedErrorFollow  ... follow the nginx log file

endef

orModules-help: export orModulesHelp:=$(orModulesHelp)
orModules-help:
	echo "$${orModulesHelp}"

SRC_LUA := $(shell find lua-modules -name '*.lua' )
LUA_MODULES  := $(patsubst lua-modules/%.lua,$(OPENRESTY_HOME)/site/lualib/$(GIT_USER)/%.lua,$(SRC_LUA))
LUA_MODULE_LOGS := $(patsubst %.lua,$(T)/%.log,$(SRC_LUA))

orModules: $(T)/orModules.log

orModulesClean: 
	@echo "## or Modules Clean ##"
	@[ -d $(OPENRESTY_HOME)/site/lualib/$(GIT_USER) ] && \
 rm -r $(OPENRESTY_HOME)/site/lualib/$(GIT_USER) || \
 echo 'lualib/$(GIT_USER) gone'
	@[ -e $(T)/orModules.log ] && rm $(T)/orModules.log || \
 echo 'orModules.log gone'
	@[ -d $(T)/lua-modules ] && rm -r $(T)/lua-modules || \
 echo ' tmp dir lua-modules gone'


watch-orModules:
	@watch -q  $(MAKE) $(LUA_MODULES)

.PHONY: watch-orModules  orModulesClean

$(OPENRESTY_HOME)/site/lualib/$(GIT_USER)/%.lua: lua-modules/%.lua 
	@echo "## $@ ##"
	@mkdir -p $(@D)
	@echo "SRC: $<" >/dev/null
	@echo 'copied files into openresty  directory' >/dev/null
	@cp $< $@

$(T)/lua-modules/%.log: $(OPENRESTY_HOME)/site/lualib/$(GIT_USER)/%.lua
	@echo "## $@ ##" 
	@[ -d @D ] || mkdir -p $(@D)
	@echo $(notdir $<) > $@

$(T)/orModules.log: $(LUA_MODULE_LOGS)
	@$(MAKE) --silent $(LUA_MODULE_LOGS)
	@echo '' > $@ 
	@for log in $(LUA_MODULE_LOGS); do \
 cat $$log >> $@ ; \
 done
	@echo "$$( sort $@ | uniq )" > $@
	@echo '------------------------------'
	@echo '|  My Lua Module In OpenResty |'
	@echo '------------------------------'
	@cat $@
	@echo '------------------------------'
	@touch $(LUA_MODULE_LOGS) 
	@echo '------------------------------'
	@echo '|  Run Test With Prove        |'
	@echo '------------------------------'
	@prove -v - < t/dev.txt
	@echo '------------------------------'

opmGet:
	@echo "install opm packages"
	@opm get pintsized/lua-resty-http
	@opm get SkyLothar/lua-resty-jwt
	@opm get bungle/lua-resty-reqargs
