# cmd:  make ngBasic
# file: mk-includes/ng-basic-conf.mk
# notes: notes/ng-config.md
####################################

define cnfBasic
# Note: worker proccess set to the amount of cpu cores
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );

# Note: error log with debug used during development
error_log logs/error.log debug;
pid       logs/nginx.pid;

pcre_jit on;
# increase limit
worker_rlimit_nofile 8000;

# nginx-config/events.conf
include events.conf;

http {
  include mime.types;

  # nginx-config/http-opt.conf
  include http-opt.conf;

  #  nginx-config/server-port80.conf
  include server-port80.conf;
}
endef

ngBasic: export cnfBasic:=$(cnfBasic)
ngBasic:
	@echo 'create basic nginx config'
	@$(MAKE) orServiceStop
	@echo "$${cnfBasic}" > $(OPENRESTY_HOME)/nginx/conf/nginx.conf
	@$(MAKE) orServiceStart
	@nmap $(DOMAIN)
	w3m -dump $(DOMAIN)
