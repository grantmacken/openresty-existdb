
# latest  versions
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

# previous versions
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
luarocksLatest: $(T)/luarocks-latest.version

checkLatest:
	@$(MAKE) orLatest
	@$(MAKE) opensslLatest
	@$(MAKE) pcreLatest
	@$(MAKE) zlibLatest


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
 --user=$(INSTALLER) \
 --group=$(INSTALLER) \
 --with-select_module \
 --with-pcre="../pcre-$(pcreVer)" \
 --with-pcre-jit \
 --with-zlib="../zlib-$(zlibVer)" \
 --with-openssl="../openssl-OpenSSL_$(opensslVer)" \
 --with-ipv6 \
 --with-file-aio \
 --with-http_v2_module \
 --with-http_ssl_module \
 --with-http_stub_status_module \
 --with-http_sub_module \
 --with-http_gzip_static_module \
 --with-http_realip_module \
 --without-http_empty_gif_module \
 --without-http_fastcgi_module \
 --without-http_uwsgi_module \
 --without-http_scgi_module \
 && make -j$(shell grep ^proces /proc/cpuinfo | wc -l ) && make install

