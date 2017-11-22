define orModulesHelp
=========================================================
MODULES : working with lua modules  - lua

```
make opmGet
make orModules
make watch-orModules
make orModules-help
make orLoggedErrorFollow
```

opmGet 
orModules
watch-orModules  ...  watch the directory
  'make orModules' will now be triggered by changes in dir
orLoggedErrorFollow  ... follow the nginx log file

endef

orModules-help: export orModulesHelp:=$(orModulesHelp)
orModules-help:
	echo "$${orModulesHelp}"

SRC_LUA := $(shell find lua-modules -name '*.lua' )
LUA_MODULES  := $(patsubst lua-modules/%.lua,$(OPENRESTY_HOME)/site/lualib/$(GIT_USER)/%.lua,$(SRC_LUA))
LUA_MODULE_LOGS := $(patsubst %.lua,$(T)/%.log,$(SRC_LUA))

opmGet:
	@echo "install opm packages"
	@opm get pintsized/lua-resty-http
	@opm get SkyLothar/lua-resty-jwt
	@opm get bungle/lua-resty-reqargs

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

