#cmd: sudo make ngPod to create this nginx.conf
# features
# main context
# - error log set off
# - set env declarations to access backend db
# http context
#  lua_code_cache off;
# server context
#  include dev-server-port443.conf
#  file: nginx-config/dev-server-port443.conf
##########################################################

define cnfPod
# Note: worker proccess set to the amount of cpu cores
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );

# Note: set env declaration to access backend db
env EXIST_AUTH;
env EXIST_HOME;
env EXIST_DATA_DIR;

error_log logs/error.log crit;
pid       logs/nginx.pid;

pcre_jit on;
# increase limit
worker_rlimit_nofile 8000;

# nginx-config/events.conf
include events.conf;

http {
  include http-lua.conf;
  # nginx-config/http-lua.conf
  include mime.types;
  # nginx-config/http-opt.conf
  include http-opt.conf;

  #  HTTP server
  #  nginx-config/server-port80-redirect.conf
  include server-port80-redirect.conf;

  #  nginx-config/dev-server.conf
  include dev-server.conf;
}

endef

ngDev: export cnfProd:=$(cnfProd)
ngDev:
	@echo "$(DOMAIN)"
	@test -d /etc/letsencrypt/
	@test -e /etc/letsencrypt//dh-param.pem
	@test -d /etc/letsencrypt/live
	@test -d /etc/letsencrypt/live/$(DOMAIN)
	@test -e /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem
	@test -e /etc/letsencrypt/live/$(DOMAIN)/privkey.pem
	@echo '#  make sure nginx conf includes in place  '
	@echo '===================================================='
	@$(MAKE) --silent ngInc
	@echo '#  recreate dev nginx config'
	@echo '===================================================='
	@echo "$${cnfProd}"
	@echo "$${cnfProd}" > $(OPENRESTY_HOME)/nginx/conf/nginx.conf
	@echo '# test conf and reload'
	@echo '===================================================='
	@$(OPENRESTY_HOME)/bin/openresty -t
	@$(OPENRESTY_HOME)/bin/openresty -s reload
	@echo '#  run our tests '
	@echo '===================================================='
	@prove -v - < t/dev.txt

# #@$(MAKE) orServiceStop
# @$(MAKE) orServiceStart
