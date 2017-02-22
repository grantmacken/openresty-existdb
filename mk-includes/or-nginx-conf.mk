#
# make ngInc
#
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

#################################
#
#  generate nginx conf file on the fly  then reload server
#  make ngBasic
#
#################################-

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

 #  HTTP server
 server {
  root html;
  index index.html;
  listen 80 default_server;
  listen [::]:80 default_server;

  server_name ~^(www\.)?(?<domain>.+)$$;
  location / {

     }
 }
}
endef

################################################################

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
  #  nginx-config/server-port80.conf
  include server-port80.conf;
  #  nginx-config/server-port443.conf
  include server-port443.conf;
}

endef

################################################################

ngTLS: export cnfTLS:=$(cnfTLS)
ngTLS:
	@echo "$(DOMAIN)"
	@echo "$${cnfTLS}"
	@test -d /etc/letsencrypt/
	@test -e /etc/letsencrypt//dh-param.pem
	@test -d /etc/letsencrypt/live
	@test -d /etc/letsencrypt/live/$(DOMAIN)
	@ls -al /etc/letsencrypt/live/$(DOMAIN)
	@test -e /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem
	@test -e /etc/letsencrypt/live/$(DOMAIN)/privkey.pem
	@ls -al /etc/letsencrypt/live/$(DOMAIN)
	@echo 'create basic TLS nginx config'
	@$(MAKE) orServiceStop
	@echo "$${cnfTLS}" > $(OPENRESTY_HOME)/nginx/conf/nginx.conf
	@$(MAKE) orServiceStart
	@nmap $(DOMAIN)
	w3m -dump $(DOMAIN)

################################################################

define cnfDev
env EXIST_AUTH;
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );
pcre_jit on;

pid       logs/nginx.pid;
error_log logs/error.log;

include events.conf;

http {
  lua_code_cache off; #only during development
  init_by_lua 'cjson = require("cjson")';
  #  SHARED DICT stays lifetime of nginx proccess
  lua_shared_dict slugDict 1m;
  lua_shared_dict dTokens 12k;

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
    set $$media $(EXIST_HOME)/$(EXIST_DATA_DIR)/fs/db/data/$$domain/;

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

   # ssl_certificate_by_lua_block {
   #   print("ssl cert by lua is running!")
   #   #TODO! handle certs using site var
   # }

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

ngBasic: export cnfBasic:=$(cnfBasic)
ngBasic:
	@echo 'create basic nginx config'
	@$(MAKE) orServiceStop
	@echo "$${cnfBasic}" > $(OPENRESTY_HOME)/nginx/conf/nginx.conf
	@$(MAKE) orServiceStart
	@nmap $(DOMAIN)
	w3m -dump $(DOMAIN)

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


