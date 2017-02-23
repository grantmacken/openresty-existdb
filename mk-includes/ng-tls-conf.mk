#
#
######################################################

define cnfTLS
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
  lua_code_cache off; #only during development
  include mime.types;
  # nginx-config/http-opt.conf
  include http-opt.conf;

  #  HTTP server
  #  nginx-config/server-port80-redirect.conf
  include server-port80-redirect.conf;

  #  nginx-config/server-port443.conf
  include server-port443.conf;
}

endef

ngTLS: export cnfTLS:=$(cnfTLS)
ngTLS:
	@echo "$(DOMAIN)"
	@echo "$${cnfTLS}"
	@test -d /etc/letsencrypt/
	@test -e /etc/letsencrypt//dh-param.pem
	@test -d /etc/letsencrypt/live
	@test -d /etc/letsencrypt/live/$(DOMAIN)
	@test -e /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem
	@test -e /etc/letsencrypt/live/$(DOMAIN)/privkey.pem
	@echo '===================================================='
	@echo 'create basic TLS nginx config'
	@$(MAKE) orServiceStop
	@echo "$${cnfTLS}" > $(OPENRESTY_HOME)/nginx/conf/nginx.conf
	@$(MAKE) orServiceStart
	@echo '===================================================='
	@nmap $(DOMAIN)
	@echo '===================================================='
	w3m -dump $(DOMAIN)
	@echo '===================================================='


#ls -al /etc/letsencrypt/live/$(DOMAIN)
