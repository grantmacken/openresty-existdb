
ifeq ($(wildcard $(T)/openresty-latest.version),)
$(shell echo '0.0.0' > $(T)/openresty-latest.version )
endif
ifeq ($(wildcard $(T)/openssl-latest.version ),)
$(shell echo '0.0.0' > $(T)/openssl-latest.version )
endif
ifeq ($(wildcard $(T)/pcre-latest.version ),)
$(shell echo '0.0.0' > $(T)/pcre-latest.version)
endif
ifeq ($(wildcard $(T)/zlib-latest.version ),)
$(shell echo '0.0.0' > $(T)/zlib-latest.version)
endif

ifeq ($(wildcard $(T)/luarocks-latest.version),)
$(shell echo '0.0.0' > $(T)/luarocks-latest.version )
endif



ifeq ($(wildcard $(T)/openresty-previous.version),)
$(shell echo '0.0.0' > $(T)/openresty-previous.version )
endif
ifeq ($(wildcard $(T)/openssl-previous.version ),)
$(shell echo '0.0.0' > $(T)/openssl-previous.version )
endif
ifeq ($(wildcard $(T)/pcre-previous.version ),)
$(shell echo '0.0.0' > $(T)/pcre-previous.version)
endif
ifeq ($(wildcard $(T)/zlib-previous.version ),)
$(shell echo '0.0.0' > $(T)/zlib-previous.version)
endif
ifeq ($(wildcard $(T)/luarocks-previous.version),)
$(shell echo '0.0.0' > $(T)/luarocks-previous.version )
endif

orLatest: $(T)/openresty-latest.version
opensslLatest: $(T)/openssl-latest.version
pcreLatest: $(T)/pcre-latest.version
zlibLatest: $(T)/zlib-latest.version

dl:
	@$(MAKE) orLatest
	@$(MAKE) opensslLatest
	@$(MAKE) pcreLatest
	@$(MAKE) zlibLatest

dl-reset:
	touch $(T)/luarocks-previous.version

luarocksLatest: $(T)/luarocks-latest.version

luaLatest: $(T)/lua-latest.version

orVer != [ -e $(T)/openresty-latest.version ] && cat $(T)/openresty-latest.version || echo ''
pcreVer != [ -e $(T)/pcre-latest.version ] && cat $(T)/pcre-latest.version || echo ''
zlibVer != [ -e $(T)/zlib-latest.version ] && cat $(T)/zlib-latest.version || echo ''
opensslVer != [ -e $(T)/openssl-latest.version ] && cat $(T)/openssl-latest.version || echo ''
luarocksVer != [ -e $(T)/luarocks-latest.version ] && cat $(T)/luarocks-latest.version || echo ''

.PHONY:  orInstall luarocksInstall ngReload \
 dl downloadOpenresty downloadOpenssl downloadPcre downloadZlib downloadRedis\
 incLetsEncrypt orInitConf openrestyService  orConf orGenSelfSigned certbotConf \
 rocks

$(T)/openresty-latest.version: $(T)/openresty-previous.version 
	@echo " $(notdir $@)"
	@[ -e $(T)/newVerAvailable.txt ] && rm $(T)/newVerAvailable.txt || echo ''
	@cp -f $@ $(<)
	@echo 'fetch the latest openresty version'
	@echo $$( curl -s -L https://openresty.org/en/download.html |\
 tr -d '\n\r' |\
 grep -oP 'openresty-\K([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)' |\
 head -1) > $(@)
	@[ "$$(<$@)" = "$$(<$(<))" ]  || echo "New $(notdir $(@)) $$(<$@) available" > $(T)/newVerAvailable.txt  && \
echo "Latest Ver: $$(<$@) is the same as Previous Ver: $$(<$(<))"
	@[ "$$(<$@)" = "$$(<$(<))" ]  || $(MAKE) downloadOpenresty
	@touch  $(<)
	@echo '------------------------------------------------'

downloadOpenresty: $(T)/openresty-latest.version
	@echo https://openresty.org/download/openresty-$(orVer).tar.gz
	@curl -L https://openresty.org/download/openresty-$(orVer).tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'

$(T)/openssl-latest.version: $(T)/openssl-previous.version
	@echo " $(notdir $@) "
	@echo 'fetch the latest opensll version'
	@cp -f $@ $(<)
	@echo $$( curl -s -L https://github.com/openssl/openssl/releases | \
 tr -d '\n\r' | \
 grep -oP 'OpenSSL_\K(\d_\d_[2-9]{1}[a-z]{1})(?=\.tar\.gz)' | \
 head -1) > $(@)
	@[ "$$(<$@)" = "$$(<$(<))" ] || echo "New $(notdir $(@)) $$(<$@) available" >> $(T)/newVerAvailable.txt  && \
echo "Latest Ver: $$(<$@) is the same as Previous Ver: $$(<$(<))"
	@[ "$$(<$@)" = "$$(<$(<))" ]  || $(MAKE) downloadOpenssl
	@touch  $(<)
	@echo '------------------------------------------------'

downloadOpenssl: $(T)/openssl-latest.version
	@echo  "$$(<$(<))" 
	@echo https://github.com/openssl/openssl/archive/OpenSSL_$(opensslVer).tar.gz 
	@curl -L https://github.com/openssl/openssl/archive/OpenSSL_$(opensslVer).tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'

$(T)/pcre-latest.version: $(T)/pcre-previous.version
	@echo "$(notdir $@) "
	@echo 'fetch the latest pcre version'
	@cp -f $@ $(<)
	@echo $$( curl -s -L ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/ | tr -d '\n\r' |\
 grep -oP 'pcre-\K([0-9\.]+)(?=\.tar\.gz)' |\
 head -1) > $(@)
	@[ "$$(<$@)" = "$$(<$(<))" ] || echo "New $(notdir $(@)) $$(<$@) available" >> $(T)/newVerAvailable.txt  && \
echo "Latest Ver: $$(<$@) is the same as Previous Ver: $$(<$(<))"
	@[ "$$(<$@)" = "$$(<$(<))" ]  || $(MAKE) downloadPcre
	@touch  $(<)
	@echo '------------------------------------------------'

downloadPcre: $(T)/pcre-latest.version
	@echo 'download the latest pcre  version'
	@echo  "$$(<$(<))" 
	curl ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$(shell echo "$$(<$(<))").tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'

$(T)/zlib-latest.version: $(T)/zlib-previous.version
	@echo " $(notdir $@) "
	@echo 'fetch the latest zlib version'
	@cp -f $@ $(<)
	@echo $$( curl -s -L http://zlib.net/ | tr -d '\n\r' |\
 grep -oP 'zlib-\K([0-9\.]+)(?=\.tar\.gz)' |\
 head -1) > $(@)
	@[ "$$(<$@)" = "$$(<$(<))" ] || echo "New $(notdir $(@)) $$(<$@) available" >> $(T)/newVerAvailable.txt  && \
echo "Latest Ver: $$(<$@) is the same as Previous Ver: $$(<$(<))"
	@[ "$$(<$@)" = "$$(<$(<))" ]  || $(MAKE) downloadZlib
	@touch  $(<)
	@echo '------------------------------------------------'

downloadZlib: $(T)/zlib-latest.version
	@echo 'download the latest  version'
	@echo  "$$(<$(<))" 
	curl http://zlib.net/zlib-$(shell echo "$$(<$(<))").tar.gz | \
 tar xz --directory $(T)
	@echo '------------------------------------------------'

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
 --with-http_sub_module \
 --with-http_gzip_static_module \
 --with-http_stub_status_module \
 --with-http_secure_link_module \
 --without-http_empty_gif_module \
 --without-http_ssi_module \
 --without-http_uwsgi_module \
 --without-http_fastcgi_module \
 --without-http_scgi_module \
 --without-lua_resty_mysql && make && make install

 # --with-http_stub_status_module \
 # --with-http_secure_link_module 
 #  -with-libatomic=../libatomic_ops-7.2 \

# https://github.com/openssl/openssl/archive/
# OpenSSL_1_0_2h.tar.gz


# curl https://www.openssl.org/source/openssl-$(shell echo "$$(<$@)").tar.gz | \
 # tar xz --directory $(T)
# @$(call chownToUser,$(@))
# @echo  "$$(<$@)" 


# @curl https://github.com/openssl/openssl/archive/openssl_$(opensslver).tar.gz | \
#  tar xz --directory $(t)



$(T)/luarocks-latest.version: $(T)/luarocks-previous.version
	@echo "{{{ $(notdir $@) "
	@echo 'fetch the latest luarocks version'
	@cp -f $@ $(<)
	@echo $$( curl -s -L  http://keplerproject.github.io/luarocks/releases/ | tr -d '\n\r' |\
 grep -oP 'luarocks-\K([0-9\.]+)(?=\.tar\.gz)' |\
 head -1) > $(@)
	@[ "$$(<$@)" = "$$(<$(<))" ]  || $(MAKE) downloadLuarocks
	@touch  $(<)


downloadLuarocks: $(T)/luarocks-latest.version
	@echo 'download the latest  version'
	@echo  "$$(<$(<))" 
	curl  http://keplerproject.github.io/luarocks/releases/luarocks-$(shell echo "$$(<$<)").tar.gz | \
	tar xz --directory $(T)
	@echo '------------------------------------------------'

preLuarocks: 
	@echo 'pre luarocks'
	@export PATH=$(OPENRESTY_HOME)/luajit/bin:$$PATH
	@cd $(OPENRESTY_HOME)/luajit/bin; ln -s luajit lua


luaJitVer =  $(shell echo "$$(luajit -v | grep -oP 'LuaJIT\s\K(\S+)')")

luarocksInstall:
	@echo 'install luarocks version'
	@echo $(luarocksVer)
	@cd $(T)/luarocks-$(luarocksVer) && \
./configure \
--prefix=$(OPENRESTY_HOME)/luajit \
--with-lua=$(OPENRESTY_HOME)/luajit \
--lua-suffix=jit-2.1.0-beta2 \
--with-lua-include=$(OPENRESTY_HOME)/luajit/include/luajit-2.1 && make && make install
	@echo '--------------------------------------------'

rocksList = xml net-url lua-resty-http lua-resty-jwt

rocks:
	@luarocks list 'xml' | grep 'xml' && luarocks show 'xml' || luarocks install 'xml' 
	@luarocks list 'net-url' | grep 'net-url' && luarocks show 'net-url' || luarocks install 'net-url' 
	@luarocks list 'lua-resty-http' | grep 'lua-resty-http' && luarocks show 'lua-resty-http' || luarocks install 'lua-resty-http' 
	@luarocks list 'lua-resty-jwt' | grep 'lua-resty-jwt' && luarocks show 'lua-resty-jwt' || luarocks install 'lua-resty-jwt' 
	@luarocks list 

downloadSiege:
	@echo 'download the latest siege version'
	@curl http://download.joedog.org/siege/siege-latest.tar.gz | \
tar xz --directory $(T)
	@echo '------------------------------------------------'
# cd $(T)/redis-stable; $(MAKE) && $(MAKE) test && $(MAKE) install
# REDIS
########################################################################

downloadRedis:
	@echo 'download the stable redis version'
	curl http://download.redis.io/redis-stable.tar.gz | \
tar xz --directory $(T)
	cd $(T)/redis-stable; $(MAKE) && $(MAKE) test && $(MAKE) install
	@echo '------------------------------------------------'


# change redis config
# daemonize no > daemonize yes 
# supervised no > supervised systemd
# dir ./ > /var/lib/redis

initRedis:
	@$(call assert-is-root)
	@$(call assert-is-systemd)
	@echo 'configure redis'
	@adduser --system --group --no-create-home redis
	@mkdir /var/lib/redis
	@chown redis:redis /var/lib/redis
	@chmod 770 /var/lib/redis

rdsConf:
	@mkdir -p $(OPENRESTY_HOME)/site/redis
	@mkdir -p openresty/site/redis/conf
	@mkdir -p openresty/site/redis/logs
	@cp $(T)/redis-stable/redis.conf openresty/site/redis/conf/redis.conf
	@sed -i 's/supervised no/supervised systemd/g' openresty/site/redis/conf/redis.conf
	@sed -i 's%pidfile /var/run/redis_6379\.pid%pidfile ./logs/redis.pid%g' openresty/site/redis/conf/redis.conf
	@$(MAKE) stow

# @sed -i 's%dir \./%dir /var/lib/redis%g' openresty/redis/conf/redis.conf
# @sed -i 's/daemonize no/daemonize yes/g' openresty/redis/redis.conf

define redisService
[Unit]
Description=Redis In-Memory Data Store
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
WorkingDirectory=$(OPENRESTY_HOME)/site/redis
PIDFile=$(OPENRESTY_HOME)/site/redis/logs/redis.pid

ExecStart=/usr/local/bin/redis-server $(OPENRESTY_HOME)/site/redis/conf/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
ExecReload=/bin/kill -USR2 $$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
endef


rdsService: export redisService:=$(redisService)
rdsService:
	@echo "setup redisService as redis.service under systemd"
	@$(call assert-is-root)
	@$(call assert-is-systemd)
	@echo 'Check if service is enabled'
	@echo "$(systemctl is-enabled redis.service)"
	@echo 'Check if service is active'
	@systemctl is-active redis.service && systemctl stop  redis.service || echo 'inactive'
	@echo "$${redisService}"
	@echo "$${redisService}" > /lib/systemd/system/redis.service
	@systemd-analyze verify redis.service
	@systemctl is-enabled redis.service || systemctl enable redis.service &&  echo 'redis service enabled'
	@systemctl start redis.service
	@echo 'Check if service is enabled'
	@systemctl is-enabled redis.service
	@echo 'Check if service is active'
	@systemctl is-active redis.service
	@echo 'Check if service is failed'
	@systemctl is-failed redis.service || echo 'OK!'
	@journalctl -u redis.service -o cat
	@echo '--------------------------------------------------------------'

#@echo 'Check if service is failed'
#@systemctl is-failed redis.service || systemctl stop redis.service && echo 'inactive'
