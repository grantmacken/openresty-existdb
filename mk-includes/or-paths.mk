
define orPath
# openresty
# --------

export OPENRESTY_HOME=$(OPENRESTY_HOME)

if [[ ! "$$PATH" == *$(OPENRESTY_HOME)/bin* ]]; then
  export PATH="$$PATH:$(OPENRESTY_HOME)/bin"
fi
endef

$(HOME)/.config/bash/openresty.sh:
	@echo 'Make sure openresty bin is on PATH'
	@mkdir -p $(dir $@)
	@$(MAKE) orPaths

orPaths:  export orPath:=$(orPath)
orPaths:
	@echo "$${orPath}" >  $(HOME)/.config/bash/openresty.sh

