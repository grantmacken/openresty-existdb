#################################
#
#  generate nginx conf file on the fly  then reload server
#
# 1.  `make orDev`  development conguration 
#   -  everything on HTTPS
#   -  lua_code_cache off;
#   flow: 
#      - remake main nginx.conf and place in $(OPENRESTY_HOME)/nginx/conf
#      - stow any new includes
#      - reload conf
# 
# 2.   `make orProd` production conguration
#   -  everything on HTTPS
#   -  lua_code_cache on;
#
# 3.  `make orBasic` basic conguration
#   -  HTTP port 80 only
#
#  1. basic port80
#  2. production  `make orProd`
#  3. development `make orDev`
#
#  conf includes outline
#   location level directives
#    routes
#      app-routes    [ for application routes ]
#      static-routes [ serving static files   ]
#      proxy-routes  [ configuring proxy locations ]
#
#################################

SRC_CONF := $(shell find nginx-config -name '*.conf' )
SRC_TYPES := $(shell find nginx-config -name '*.types' )
NGX  := $(patsubst nginx-config/%,$(OPENRESTY_HOME)/nginx/conf/%,$(SRC_CONF) $(SRC_TYPES))

ngConf: $(NGX)

watch-nginx-conf:
	@watch -q $(MAKE) ngConf

.PHONY:  watch-nginx-conf


$(OPENRESTY_HOME)/nginx/conf/%.conf: nginx-config/%.conf
	@echo "## $@ ##"
	@mkdir -p $(@D)
	@echo "SRC: $<" >/dev/null
	@echo 'copied files into openresty  directory' >/dev/null
	@cp $< $@
	@echo '-----------------------------------------------------------------'

$(OPENRESTY_HOME)/nginx/conf/%.types: nginx-config/%.types
	@echo "## $@ ##"
	@mkdir -p $(@D)
	@echo "SRC: $<" >/dev/null
	@echo 'copied files into openresty  directory' >/dev/null
	@cp $< $@
	@echo '-----------------------------------------------------------------'

define cnfDev
env EXIST_AUTH;
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );
pcre_jit on;

pid       logs/nginx.pid;
error_log logs/error.log;

# error_log syslog:server=unix:/dev/log;

include events.conf;

http {
  lua_code_cache off; #only during development
  init_by_lua 'cjson = require("cjson")';
  #  SHARED DICT stays lifetime of nginx proccess
  lua_shared_dict slugDict 1m;

  include mime.types;
  include accessLog.conf;

  # access_log syslog:server=unix:/dev/log;
  # HTTPS server 
  server {
    listen 443      ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    # server_name $(DOMAIN);
# A named regular expression capture can be used later as a variable: 
    server_name  ~^(www\.)?(?<domain>.+)$$;
    # GLOBAL VARIABLES
    set $$site  $$domain;
    set $$resources $(EXIST_HOME)/$(EXIST_DATA_DIR)/fs/db/apps/$$domain/;

    ssl_certificate_by_lua_block {
      print("ssl cert by lua is running!")
      #TODO! handle certs using site var
    }

    # certificates from letsencrypt
    ssl_certificate         /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem;
    # Path to private key used to create certificate.
    ssl_certificate_key     /etc/letsencrypt/live/$(DOMAIN)/privkey.pem; 

    include tls.conf;

    # disable  Enable OCSP Stapling 
    include ocspStapling.conf;
    # verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/$(DOMAIN)/chain.pem;

    server_tokens off;
    resolver '8.8.8.8' ipv6=off;



    # PHASES 
    # before locations insert server-rewrite phase

    include serverRewrite.conf;
    # gf:  openresty/nginx/conf/serverRewrite.conf

    include locationBlocks.conf;
    # gf:  openresty/nginx/conf/locationBlocks.conf

  }

  # HTTP server on port 80
  include http.conf;

}
endef


################################################################

define cnfProd
env EXIST_AUTH;
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );
pcre_jit on;

pid       logs/nginx.pid;
error_log logs/error.log;

include events.conf;

http {
  init_by_lua 'cjson = require("cjson")';
  #  SHARED DICT stays lifetime of nginx proccess
  lua_shared_dict slugDict 1m;

  include mime.types;
  include accessLog.conf;

  # access_log syslog:server=unix:/dev/log;
  # HTTPS server 
  server {
    listen 443      ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name $(DOMAIN);

    ssl_certificate_by_lua_block {
      print("ssl cert by lua is running!")
    }
    # certificates from letsencrypt
    ssl_certificate         /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem;
    # Path to private key used to create certificate.
    ssl_certificate_key     /etc/letsencrypt/live/$(DOMAIN)/privkey.pem; 

    include tls.conf;

    # disable  Enable OCSP Stapling 
    include ocspStapling.conf;
    # verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/$(DOMAIN)/chain.pem;

    server_tokens off;
    resolver '8.8.8.8' ipv6=off;

    # GLOBAL VARIABLES

    set $$resources $(EXIST_HOME)/$(EXIST_DATA_DIR)/fs/db/apps/$(DOMAIN)/;

    # PHASES 
    # before locations insert server-rewrite phase

    include serverRewrite.conf;
    # gf:  openresty/nginx/conf/serverRewrite.conf

    include locationBlocks.conf;
    # gf:  openresty/nginx/conf/locationBlocks.conf

  }
  # HTTP server on port 80
  include http.conf;

}
endef

################################################################

define cnfPort80
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );
error_log logs/error.log;
pid       logs/nginx.pid;

events {
  worker_connections  1024;
}

http {
  include mime.types;
  access_log off;

  # HTTP server on port 80
  include http.conf;

}
endef

################################################################

orBasic: export cnfPort80:=$(cnfPort80)
orBasic:
	@echo 'create basic nginx config'
	@echo "$${cnfPort80}" > $@
	@echo "$${cnfPort80}" > $(OPENRESTY_HOME)/nginx/conf/nginx.conf
	@$(MAKE) orReload

orProd: export cnfProd:=$(cnfProd)
orProd:
	@echo 'create nginx production conf'
	@echo "$${cnfProd}" >  $(OPENRESTY_HOME)/nginx/conf/nginx.conf
	@$(MAKE) orReload

orDev: export cnfDev:=$(cnfDev)
orDev:
	@echo 'create nginx dev conf'
	@echo "$(OPENRESTY_HOME)/nginx/conf/nginx.conf"
	@echo "$${cnfDev}"
	@echo "$${cnfDev}" > $(OPENRESTY_HOME)/nginx/conf/nginx.conf
	@$(call chownToUser,$(OPENRESTY_HOME)/nginx/conf/nginx.conf)
	@echo '---------------------------------------------'

orReload:
	@$(OPENRESTY_HOME)/bin/openresty -t
	@$(OPENRESTY_HOME)/bin/openresty -s reload

ngClean:
	@echo 'clean out nginx conf dir but leave mimetypes'
	@find $(OPENRESTY_HOME)/nginx/conf -type f -name '*.default' -delete
	@find $(OPENRESTY_HOME)/nginx/logs -type f -name 'error.log' -delete
	@find $(OPENRESTY_HOME)/nginx/conf -type f -name '*.conf' -delete
	@find $(OPENRESTY_HOME)/nginx/conf -type f -name '*_params' -delete

/etc/letsencrypt/dh-param.pem: 
	@mkdir -p $(dir $@)
	@echo 'create a 2048-bits Diffie-Hellman parameter file that nginx can use'
	@openssl dhparam -out $@ 2048
