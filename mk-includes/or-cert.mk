
#########################################################
# SSL CONFIGERATION note  
# can not be done on local dev server 
#########################################################

define certbotConfig

rsa-key-size = 2048

# Uncomment and update to register with the specified e-mail address
email = $(GIT_EMAIL)

# Uncomment and update to generate certificates for the specified
# domains.
domains = $(MY_DOMAINS)

# use a text interface instead of ncurses
text = true

# use the webroot authenticator. 
# set path to the default html dir 
authenticator = webroot
webroot-path = $(OPENRESTY_HOME)/nginx/html

agree-tos = true

endef

/etc/letsencrypt/cli.ini: export certbotConfig:=$(certbotConfig)
/etc/letsencrypt/cli.ini:
	@[ -d  $(dir $@) ] || mkdir $(dir $@)
	@echo "create cli config file"
	@echo "$${certbotConfig}"
	@echo "$${certbotConfig}" >  $@

$(T)/certbot/certbot-auto: /etc/letsencrypt/cli.ini
	@[ -d  $(dir $@) ] || mkdir $(dir $@)
	@[ -e $@ ] && \
 echo 'Certbot installed ... ' || \
 curl https://dl.eff.org/certbot-auto -o $@ 
	@$(call chownToUser,$@)
	@chmod +x $@

/etc/letsencrypt/dh-param.pem: $(T)/certbot/certbot-auto
	@[ -d  $(dir $@) ] || mkdir -p $(dir $@)
	@[ -e $@ ] && \
 echo ' Diffie-Hellman parameter created ... '  ||\
 openssl dhparam -out $@ 2048

certInit: /etc/letsencrypt/dh-param.pem

certRenew:
	@echo "renew my certs"
	@$(T)/certbot/certbot-auto certonly
	@$(MAKE) ngReload:

certConfig: config
	@rm /etc/letsencrypt/cli.ini
	@$(MAKE) certInit
	@touch config

# NOTE: SERVER is named in config file
#       It is the VPS server host that can be connected to via ssh
#       and will be
#       Host {name} defined in
#       gf: ~/.ssh/config
#       A distro upgrade will destroy /etc/letsencrypt
#       on local dev use sudo to remake and set permissions for dir
#       then secure copy certs from remote


syncCerts:
	@echo 'copy certs from remote'
	@scp -r $(SERVER):/etc/letsencrypt/live /etc/letsencrypt
	@scp  $(SERVER):/etc/letsencrypt/dh-param.pem /etc/letsencrypt/

syncCertsPerm:
	@echo 'copy certs from remote'
	@$(call assert-is-root)
	@[ -d /etc/letsencrypt ] || mkdir /etc/letsencrypt
	@$(call chownToUser, /etc/letsencrypt )
	@$(call chownToUser, /tmp)
	@ls -al /etc/letsencrypt 

scpAccessToken:
	@echo 'copy current access token over to remote'
	@echo '$(SERVER):~/$(GIT_USER)'
	@echo '$(abspath  $(ACCESS_TOKEN_PATH))'
	@scp $(abspath  $(ACCESS_TOKEN_PATH)) $(SERVER):~/$(GIT_USER)/
	@scp $(abspath  $(SITE_TOKEN_PATH)) $(SERVER):~/$(GIT_USER)/
	@scp $(abspath  $(TWITTER_CREDENTIALS)) $(SERVER):~/$(GIT_USER)/
