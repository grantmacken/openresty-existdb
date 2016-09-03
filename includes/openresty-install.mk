
orLatest: $(T)/openresty-latest.version
opensslLatest: $(T)/openssl-latest.version
pcreLatest: $(T)/pcre-latest.version
zlibLatest: $(T)/zlib-latest.version
luarocksLatest: $(T)/luarocks-latest.version
luaLatest: $(T)/lua-latest.version

orVer != [ -e $(T)/openresty-latest.version ] && cat $(T)/openresty-latest.version || echo ''
pcreVer != [ -e $(T)/pcre-latest.version ] && cat $(T)/pcre-latest.version || echo ''
zlibVer != [ -e $(T)/zlib-latest.version ] && cat $(T)/zlib-latest.version || echo ''
opensslVer != [ -e $(T)/openssl-latest.version ] && cat $(T)/openssl-latest.version || echo ''
luarocksVer != [ -e $(T)/luarocks-latest.version ] && cat $(T)/luarocks-latest.version || echo ''


.PHONY: orInstall luarocksInstall ngReload \
 downloadOpenresty downloadOpenssl downloadPcre downloadZlib downloadRedis\
 incLetsEncrypt orInitConf openrestyService  orConf orGenSelfSigned certbotConf

$(T)/openresty-latest.version: config
	@echo " $(notdir $@) "
	@echo 'fetch the latest openresty version'
	@echo $$( curl -s -L https://openresty.org/en/download.html |\
 tr -d '\n\r' |\
 grep -oP 'openresty-\K([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)' |\
 head -1) > $(@)
	@echo  "$$(<$@)" 
	@echo '------------------------------------------------'

downloadOpenresty: $(T)/openresty-latest.version
	@echo https://openresty.org/download/openresty-$(orVer).tar.gz
	@curl -L https://openresty.org/download/openresty-$(orVer).tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'

# curl $https://openresty.org/download/openresty-$(shell echo  "$$(<$@)" ).tar.gz | \
#  tar xz --directory $(T)

orInstall: $(T)/openresty-latest.version 
	@echo "configure and install openresty $$(<$(<))"
	@echo "$(pcreVer)"
	@echo "$(zlibVer)"
	@echo "$(opensslVer)"
	@cd $(T)/openresty-$$(<$(<));\
 ./configure \
 --with-select_module \
 --with-pcre="../pcre-$(pcreVer)" \
 --with-pcre-jit \
 --with-zlib="../zlib-$(zlibVer)" \
 --with-openssl="../openssl-OpenSSL_$(opensslVer)" \
 --with-http_ssl_module \
 --with-ipv6 \
 --with-http_v2_module \
 --with-file-aio \
 --with-http_realip_module \
 --with-http_gzip_static_module \
 --without-http_redis_module \
 --without-http_redis2_module \
 --without-http_uwsgi_module \
 --without-http_fastcgi_module \
 --without-http_scgi_module \
 --without-lua_resty_mysql && make && make install

 # --with-http_stub_status_module \
 # --with-http_secure_link_module 

# https://github.com/openssl/openssl/archive/
# OpenSSL_1_0_2h.tar.gz

$(T)/openssl-latest.version: config
	@echo " $(notdir $@) "
	@echo 'fetch the latest opensll version'
	@echo $$( curl -s -L https://github.com/openssl/openssl/releases | \
 tr -d '\n\r' | \
 grep -oP 'OpenSSL_\K(\d_\d_[2-9]{1}[a-z]{1})(?=\.tar\.gz)' |\
 head -1) > $(@)
	@echo '$(opensslVer)'
	@echo '------------------------------------------------'

# curl https://www.openssl.org/source/openssl-$(shell echo "$$(<$@)").tar.gz | \
 # tar xz --directory $(T)
# @$(call chownToUser,$(@))
# @echo  "$$(<$@)" 

downloadOpenssl: $(T)/openssl-latest.version
	@echo  "$$(<$(<))" 
	@echo https://github.com/openssl/openssl/archive/OpenSSL_$(opensslVer).tar.gz 
	@curl -L https://github.com/openssl/openssl/archive/OpenSSL_$(opensslVer).tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'

# @curl https://github.com/openssl/openssl/archive/openssl_$(opensslver).tar.gz | \
#  tar xz --directory $(t)

$(T)/pcre-latest.version: config
	@echo "$(notdir $@) "
	@echo 'fetch the latest pcre version'
	@echo $$( curl -s -L ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/ | tr -d '\n\r' |\
 grep -oP 'pcre-\K([0-9\.]+)(?=\.tar\.gz)' |\
 head -1) > $(@)
	@echo  "$$(<$@)" 
	@echo '------------------------------------------------'

downloadPcre: $(T)/pcre-latest.version
	@echo 'download the latest pcre  version'
	@echo  "$$(<$(<))" 
	curl ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$(shell echo "$$(<$(<))").tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'


$(T)/zlib-latest.version: config
	@echo " $(notdir $@) "
	@echo 'fetch the latest zlib  version'
	@echo 'http://zlib.net/'
	@echo $$( curl -s -L http://zlib.net/ | tr -d '\n\r' |\
 grep -oP 'zlib-\K([0-9\.]+)(?=\.tar\.gz)' |\
 head -1) > $(@)
	@echo  "$$(<$@)" 
	@echo '------------------------------------------------'

downloadZlib: $(T)/zlib-latest.version
	@echo 'download the latest  version'
	@echo  "$$(<$(<))" 
	curl http://zlib.net/zlib-$(shell echo "$$(<$(<))").tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'


$(T)/luarocks-latest.version: config
	@echo "{{{ $(notdir $@) "
	@echo 'fetch the latest luarocks version'
	@echo $$( curl -s -L  http://keplerproject.github.io/luarocks/releases/ | tr -d '\n\r' |\
 grep -oP 'luarocks-\K([0-9\.]+)(?=\.tar\.gz)' |\
 head -1) > $(@)
	curl  http://keplerproject.github.io/luarocks/releases/luarocks-$(shell echo "$$(<$@)").tar.gz | \
 tar xz --directory $(T)
	@$(call chownToUser,$(@))
	@echo  "$$(<$@)" 
	@echo '------------------------------------------------'

luarocksInstall:
	@echo 'install luarocks version'
	@echo $(luarocksVer)
	@cd $(T)/luarocks-$(luarocksVer) && \
 ./configure \
 --prefix=$(OPENRESTY_HOME)/luajit \
 --with-lua=$(OPENRESTY_HOME)/luajit \
 --lua-suffix=jit-2.1.0-beta2 \
 --with-lua-include=$(OPENRESTY_HOME)/luajit/include/luajit-2.1 && make && make install
	@export PATH=$(OPENRESTY_HOME)/luajit/bin:$$PATH
	@cd $(OPENRESTY_HOME)/luajit/bin; ln -s luajit lua
	@echo '--------------------------------------------'

downloadRedis:
	@echo 'download the stable redis version'
	curl http://download.redis.io/redis-stable.tar.gz | \
 tar xz --directory $(T)
	cd $(T)/redis-stable; $(MAKE) && $(MAKE) test && $(MAKE) install
	@echo '------------------------------------------------'

downloadSiege:
	@echo 'download the latest siege version'
	@curl http://download.joedog.org/siege/siege-latest.tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'
# cd $(T)/redis-stable; $(MAKE) && $(MAKE) test && $(MAKE) install

##################################
#
# Set up openresty as a service
# 
#  openresty now symlinked to usr/local/openresty/bin
#
##################################

define openrestyService
[Unit]
Description=OpenResty stack for Nginx HTTP server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=$(NGINX_HOME)/logs/nginx.pid
ExecStartPre=$(OPENRESTY_HOME)bin/openresty -t
ExecStart=$(OPENRESTY_HOME)/bin/openresty
ExecReload=/bin/kill -s HUP $$MAINPID
ExecStop=/bin/kill -s QUIT $$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
endef

orService: export openrestyService:=$(openrestyService)
orService:
	@echo "setup openresty as nginx.service under systemd"
	@$(call assert-is-root)
	@$(call assert-is-systemd)
	@echo 'Check if service is enabled'
	@echo "$(systemctl is-enabled nginx.service)"
	@echo 'Check if service is active'
	@systemctl is-active nginx.service && systemctl stop  nginx.service || echo 'inactive'
	@echo 'Check if service is failed'
	@systemctl is-failed nginx.service || systemctl stop nginx.service && echo 'inactive'
	@echo "$${ngService}"
	@echo "$${ngService}" > /lib/systemd/system/nginx.service
	@systemd-analyze verify nginx.service
	@systemctl is-enabled nginx.service || systemctl enable nginx.service
	@systemctl start nginx.service
	@echo 'Check if service is enabled'
	@systemctl is-enabled nginx.service
	@echo 'Check if service is active'
	@systemctl is-active nginx.service
	@echo 'Check if service is failed'
	@systemctl is-failed nginx.service || echo 'OK!'
	@journalctl -f -u nginx.service -o cat
	@echo '--------------------------------------------------------------'



