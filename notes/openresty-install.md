
# OpenResty Install

```
 make orInstall
```

Automates the openresty installl 
 
Established latest version of sources,
then if required downloads the  source archive.

- openresty
- zlib : zip libarary
- pcre : perl reg ex  
- openssl 

Installs and compliles from latest sources.

Alter to fit your requirements the configurable options target. `mk-includes/or-install.mk

```
orInstall:
	@echo "configure and install $(shell cat $(T)/openresty-latest.version) "
	@[ -d $(T)/$(shell cat $(T)/pcre-latest.version) ] && \
 echo " $(shell cat $(T)/pcre-latest.version) "
	@[ -d $(T)/$(shell cat $(T)/zlib-latest.version) ] && \
 echo " $(shell cat $(T)/zlib-latest.version) "
	@[ -d $(T)/openssl-$(shell cat $(T)/openssl-latest.version) ] && \
 echo " $(shell cat $(T)/openssl-latest.version) "
	@[ -d $(T)/$(shell cat $(T)/openresty-latest.version) ] && \
 cd $(T)/$(shell cat $(T)/openresty-latest.version);\
 ./configure \
 --user=$(INSTALLER) \
 --group=$(INSTALLER) \
 --with-pcre="../$(shell cat $(T)/pcre-latest.version)" \
 --with-pcre-jit \
 --with-zlib="../$(shell cat $(T)/zlib-latest.version)" \
 --with-openssl="../openssl-$(shell cat $(T)/openssl-latest.version)" \
 --with-select_module \
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

```





