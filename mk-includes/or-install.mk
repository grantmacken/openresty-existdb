
$(T)/openresty-latest.version:
	@echo " $(notdir $@)"
	@echo 'fetch the latest openresty version'
	@echo $$( curl -s -L https://openresty.org/en/download.html |\
 tr -d '\n\r' |\
 grep -oP 'openresty-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)' |\
 head -1) > $(@)
	@cat $@

downloadOpenresty: $(T)/openresty-latest.version
	@[ -d $(T)/$(shell cat $<) ] && echo '$(shell cat $<) downloaded ...' || echo  'download ... $(shell cat $<)'
	@[ -d $(T)/$(shell cat $<) ] || \
 curl -L https://openresty.org/download/$(shell cat $<).tar.gz | \
 tar xz --directory $(T)

$(T)/openssl-latest.version: 
	@echo " $(notdir $@) "
	@echo 'fetch the latest opensll version'
	@echo $$( curl -s -L https://github.com/openssl/openssl/releases | \
 tr -d '\n\r' | \
 grep -oP 'OpenSSL_(\d_\d_[2-9]{1}[a-z]{1})(?=\.tar\.gz)' | \
 head -1) > $(@)
	@cat $@

#note the prefix 'openssl-'

downloadOpenssl: $(T)/openssl-latest.version
	@[ -d $(T)/openssl-$(shell cat $<) ] && echo '$(shell cat $<) downloaded ...' || echo  'download ... $(shell cat $<)'
	@[ -d $(T)/openssl-$(shell cat $<) ] || \
 curl -L https://github.com/openssl/openssl/archive/$(shell cat $<).tar.gz | \
 tar xz --directory $(T)

$(T)/pcre-latest.version:
	@echo "$(notdir $@) "
	@echo 'fetch the latest pcre version'
	@echo $$( curl -s -L ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/ | tr -d '\n\r' |\
 grep -oP 'pcre-[0-9\.]+(?=\.tar\.gz)' |\
 head -1) > $(@)
	@cat $@
	@echo '------------------------------------------------'

downloadPcre: $(T)/pcre-latest.version
	@[ -d $(T)/$(shell cat $<) ] && echo '$(shell cat $<) downloaded ...' || echo  'download ... $(shell cat $<)'
	@[ -d $(T)/$(shell cat $<) ] || \
 curl ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/$(shell cat $<).tar.gz | \
 tar xz --directory $(T)
# @echo '------------------------------------------------'

$(T)/zlib-latest.version:
	@echo 'fetch the latest zlib version'
	@echo $$( curl -s -L http://zlib.net/ | tr -d '\n\r' |\
 grep -oP 'zlib-[0-9\.]+(?=\.tar\.gz)' |\
 head -1) > $(@)
	@cat $@
	@echo '------------------------------------------------'

downloadZlib: $(T)/zlib-latest.version
	@[ -d $(T)/$(shell cat $<) ] && echo '$(shell cat $<) downloaded ...' || echo  'download ... $(shell cat $<)'
	@[ -d $(T)/$(shell cat $<) ] || \
 curl -L http://zlib.net/$(shell cat $<).tar.gz | \
 tar xz --directory $(T)


#rm $(T)/*-latest.version 2>/dev/null || echo 'latest versions gone'
orInstallDownload: 
	@$(MAKE) --silent downloadOpenresty
	@$(MAKE) --silent downloadOpenssl
	@$(MAKE) --silent downloadPcre
	@$(MAKE) --silent downloadZlib

orInstall: orInstallDownload
orInstall:
	rm $(T)/*-latest.version 2>/dev/null || echo 'latest versions gone'
	@echo "configure and install $(shell cat $(T)/openresty-latest.version) "
	@[ -d $(T)/$(shell cat $(T)/pcre-latest.version) ] &&  echo " $(shell cat $(T)/pcre-latest.version) "
	@[ -d $(T)/$(shell cat $(T)/zlib-latest.version) ] &&  echo " $(shell cat $(T)/zlib-latest.version) "
	@[ -d $(T)/openssl-$(shell cat $(T)/openssl-latest.version) ] &&  echo " $(shell cat $(T)/openssl-latest.version) "
	@[ -d $(T)/$(shell cat $(T)/openresty-latest.version) ] &&  cd $(T)/$(shell cat $(T)/openresty-latest.version);\
 ./configure \
 --user=$(INSTALLER) \
 --group=$(INSTALLER) \
 --with-select_module \
 --with-pcre="../$(shell cat $(T)/pcre-latest.version)" \
 --with-pcre-jit \
 --with-zlib="../$(shell cat $(T)/zlib-latest.version)" \
 --with-openssl="../openssl-$(shell cat $(T)/openssl-latest.version)" \
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

