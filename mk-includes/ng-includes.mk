
# make ngInc
######################################################################################

SRC_CONF := $(shell find nginx-config -name '*.conf' )
NGX  := $(patsubst nginx-config/%,$(OPENRESTY_HOME)/nginx/conf/%,$(SRC_CONF))

ngInc: $(NGX)

watch-ngInc:
	@watch -q $(MAKE) ngInc

.PHONY:  watch-ngInc

$(OPENRESTY_HOME)/nginx/conf/%.conf: nginx-config/%.conf
	@echo "## $@ ##"
	@mkdir -p $(@D)
	@echo "SRC: $<" >/dev/null
	@cp $<  $(@D)
	@echo 'copied files into openresty  directory' >/dev/null

ngReload:
	@sudo $(OPENRESTY_HOME)/bin/openresty -t
	@sudo $(OPENRESTY_HOME)/bin/openresty -s reload

ngTest:
	@sudo $(OPENRESTY_HOME)/bin/openresty -t

ngClean:
	@echo 'clean out nginx conf dir but leave mimetypes'
	@find $(OPENRESTY_HOME)/nginx/conf -type f -name '*.default' -delete
	@find $(OPENRESTY_HOME)/nginx/logs -type f -name 'error.log' -delete
	@find $(OPENRESTY_HOME)/nginx/conf -type f -name '*.conf' -delete
	@find $(OPENRESTY_HOME)/nginx/conf -type f -name '*_params' -delete


