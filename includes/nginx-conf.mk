#################################
#
# simple setup prior to letsencrypt
#
#################################

define cnfBase80
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

openresty/nginx/conf/base80.conf: export cnfBase80:=$(cnfBase80)
openresty/nginx/conf/base80.conf:
	@echo 'create base 80'
	@echo "$${cnfBase80}" > $@
	@echo "$${cnfBase80}" > openresty/nginx/conf/nginx.conf

################################################################

define cnfBase443
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

openresty/nginx/conf/base443.conf: export cnfBase443:=$(cnfBase443)
openresty/nginx/conf/base443.conf:
	@echo 'create base'
	@echo "$${cnfBase443}" > $@
	@echo "$${cnfBase443}" > openresty/nginx/conf/nginx.conf

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
