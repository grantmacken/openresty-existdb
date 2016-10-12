#################################
#
#  generate nginx conf file on the fly  then reload server
#  
# 1.  `make orDev`  development conguration 
#   -  everything on HTTPS
#   -  lua_code_cache off;
#   flow: 
#      - remake main nginx.conf and place in $(NGINX_HOME)/conf
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

define cnfProd
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );
error_log logs/error.log;
pid       logs/nginx.pid;

include events.conf;

http {
  include mime.types;
  include accessLog.conf;

  # HTTPS server 
  server {
    listen 443      ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;

    server_name ~^(www\.)?(?<domain>.+)$$;

    # certificates from letsencrypt
    ssl_certificate         /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem;
    # Path to private key used to create certificate.
    ssl_certificate_key     /etc/letsencrypt/live/$(DOMAIN)/privkey.pem;

    include tls.conf;

    include ocspStapling.conf;
    # verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/$(DOMAIN)/chain.pem;

    # PHASES - rewrite, access, content, log
    # rewrite phase
    include rewrites.conf;
    include locations.conf;

    location /hello {
      default_type text/html;
      content_by_lua '
      ngx.say("<p>hello, world</p>")
      ';
     }
  }

  # HTTP server on port 80
  include http.conf;

}
endef

################################################################

define cnfDev
env EXIST_AUTH;
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );
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

    # PHASES - rewrite, access, content, log
    # rewrite phase
    #include rewrites.conf;

    server_tokens off;
    resolver '8.8.8.8' ipv6=off;

    include routes/*;
  }

  # HTTP server on port 80
  include http.conf;

}
endef

################################################################

orBasic: export cnfPort80:=$(cnfPort80)
orBasic:
	@echo 'create basic nginx config'
	@echo "$${cnfPort80}" > $@
	@echo "$${cnfPort80}" > $(NGINX_HOME)/conf/nginx.conf
	@$(MAKE) orReload

orProd: export cnfProd:=$(cnfProd)
orProd:
	@echo 'create nginx production conf'
	@echo "$${cnfProd}" >  $(NGINX_HOME)/conf/nginx.conf
	@$(MAKE) orReload

orDev: export cnfDev:=$(cnfDev)
orDev:
	@echo 'create nginx dev conf'
	@echo "$(NGINX_HOME)/conf/nginx.conf"
	@echo "$${cnfDev}"
	@echo "$${cnfDev}" > $(NGINX_HOME)/conf/nginx.conf
	@$(call chownToUser,$(NGINX_HOME)/conf/nginx.conf)
	@$(MAKE) stow
	@$(MAKE) orReload
	@echo '---------------------------------------------'

orReload:
	@$(OPENRESTY_HOME)/bin/openresty -t
	@$(OPENRESTY_HOME)/bin/openresty -s reload

ngClean:
	@echo 'clean out nginx conf dir but leave mimetypes'
	@find $(NGINX_HOME)/conf -type f -name 'fast*' -delete
	@find $(NGINX_HOME)/conf -type f -name 'scgi*' -delete
	@find $(NGINX_HOME)/conf -type f -name 'uwsgi*' -delete
	@find $(NGINX_HOME)/conf -type f -name '*.default' -delete
	@find $(NGINX_HOME)/logs -type f -name 'error.log' -delete
	@find $(NGINX_HOME)/conf -type f -name 'koi-*' -delete
	@find $(NGINX_HOME)/conf -type f -name 'win-*' -delete
	@find $(NGINX_HOME)/conf -type f -name 'nginx.conf' -delete

openresty/nginx/ssl/dh-param.pem: 
	@mkdir -p $(dir $@)
	@[ -e $(NGINX_HOME)/ssl/dh-param.pem  ] || \
 echo 'create a 2048-bits Diffie-Hellman parameter file that nginx can use'
	@openssl dhparam -out $@ 2048
	@$(MAKE) stow
