

SRC_LUA := $(shell find lua-modules -name '*.lua' )
LUA_MODULES  := $(patsubst lua-modules/%.lua,$(OPENRESTY_HOME)/site/lualib/mod/%.lua,$(SRC_LUA))

lua-modules: $(LUA_MODULES)

watch-lua-modules:
	@watch -q $(MAKE) lua-modules

.PHONY:  watch-lua-modules 

$(OPENRESTY_HOME)/site/lualib/mod/%.lua: lua-modules/%.lua 
	@echo "## $@ ##"
	@mkdir -p $(@D)
	@echo "SRC: $<" >/dev/null
	@echo 'copied files into openresty  directory' >/dev/null
	@cp $< $@
	@echo '-----------------------------------------------------------------'


opmGet:
	@echo "install opm packages"
	<@opm get pintsized/lua-resty-http
	@opm get SkyLothar/lua-resty-jwt
	@opm get bungle/lua-resty-reqargs
