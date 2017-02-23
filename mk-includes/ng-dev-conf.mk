

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
