define ngConf
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );
error_log logs/error.log;

events {
  multi_accept       on;
  worker_connections 1024;
  use                epoll;
}

http {
  sendfile on;
  aio on;
  directio 2m;
  include mime.types;
  tcp_nodelay on;
  tcp_nopush on;

  default_type application/octet-stream;

  # A DNS resolver must be defined for OCSP stapling to function.
  resolver 8.8.8.8;

  access_log off;

  # HTTPS server 
  server {
    listen 443      ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;

    server_name ~^(www\.)?(?<domain>.+)$$;

    # certificates from letsencrypt
    ssl_certificate         /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/$(DOMAIN)/privkey.pem;

    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Diffie-Hellman parameter for DHE ciphersuites
    ssl_dhparam ../ssl/dh-param.pem;

    # modern configuration.
    # use only TLS 1.2
    ssl_protocols TLSv1.2;
    ssl_prefer_server_ciphers on;
    # https://wiki.mozilla.org/Security/Server_Side_TLS
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';


    # HSTS (ngx_http_headers_module is required) (15768000 seconds = 6 months)
    add_header Strict-Transport-Security max-age=15768000;

    # OCSP Stapling ---
    # fetch OCSP records from URL in ssl_certificate and cache them
     ssl_stapling on;
     ssl_stapling_verify on;

    # verify chain of trust of OCSP response using Root CA and Intermediate certs
     ssl_trusted_certificate /etc/letsencrypt/live/$(DOMAIN)/chain.pem;

    location / {
      default_type text/html;
      content_by_lua '
      ngx.say("<p>hello, world</p>")
      ';
     }
  }

   # HTTP server
  server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name ~^(www\.)?(?<domain>.+)$$;

    # Endpoint used for performing domain verification with Let's Encrypt.
    include letsencrypt.conf;
 
    # Redirect all HTTP requests to HTTPS with a 301 Moved Permanently response.
    location / {
      return 301 https://$$http_host$$request_uri;
    }
  }
}
endef

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


#################################
#
# setup letsencrypt
#
#################################

define cnfLetsEncrypt
  location /.well-known/acme-challenge {
    default_type "text/plain";
    allow all;
    }
endef

incLetsEncrypt: export cnfLetsEncrypt:=$(cnfLetsEncrypt)
incLetsEncrypt:
	@echo "$${cnfLetsEncrypt}" > $(NGINX_HOME)/conf/letsencrypt.conf

define cnfBase
worker_processes $(shell grep ^proces /proc/cpuinfo | wc -l );
error_log logs/error.log;
pid       logs/nginx.pid;

events {
  worker_connections  1024;
}

http {
  include mime.types;
  access_log off;
  
  # port 80 HTTP server
  include http.conf
  }
}
endef

openresty/nginx/conf/base.conf: export cnfBase:=$(cnfBase)
openresty/nginx/conf/base.conf:
	@echo 'create base'
	@echo "$${cnfInitBase}" > $@
	@$(MAKE) stow

orConf: export ngConf:=$(ngConf)
orConf:
	@echo "$${ngConf}" > $(NGINX_HOME)/conf/nginx.conf
	@$(MAKE) orReload

orReload:
	@$(OPENRESTY_HOME)/bin/openresty -t
	@$(OPENRESTY_HOME)/bin/openresty -s reload

nginx-openresty-config: export nginxConfig:=$(nginxConfig)
nginx-open-resty-config:
	@echo "$(NGINX_CONFIG)"
	@[ -d $(NGINX_HOME)/proxy ] || mkdir $(NGINX_HOME)/proxy
	@[ -d $(NGINX_HOME)/cache ] || mkdir $(NGINX_HOME)/cache
	@cp -f nginx-config/*  $(NGINX_HOME)/conf
	@echo "$${nginxConfig}" > $(NGINX_CONFIG)
	@$(NGINX_HOME)/sbin/nginx -t 
	@ps -lfC nginx | grep master && $(NGINX_HOME)/sbin/nginx -s reload 
	echo "$$($(NGINX_HOME)/sbin/nginx -t -q)"



