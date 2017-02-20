
#########################################################
# 
# SSL CONFIGERATION note  
#
# can not be done on local dev server 
#
# use cerbot-auto with configuration file
# 
# testing
# https://www.ssllabs.com/ssltest/analyze.html?d=gmack.nz
# https://certlogik.com/ssl-checker/gmack.nz/summary
# https://certlogik.com/ssl-checker/gmack.nz/
#
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
	@[ -d  $(dir $@)] || mkdir $(dir $@)
	@echo "create cli config file"
	@echo "$${certbotConfig}"
	@echo "$${certbotConfig}" >  $@

$(T)/certbot/certbot-auto: /etc/letsencrypt/cli.ini
	@[ -d  $(dir $@)] || mkdir $(dir $@)
	@[ -e $@ ] || curl https://dl.eff.org/certbot-auto -o $@ 
	@$(call chownToUser,$@)
	@chmod +x $@
	@$(@) --help

/etc/letsencrypt/dh-param.pem: $(T)/certbot/certbot-auto
	@mkdir -p $(dir $@)
	@echo 'create a 2048-bits Diffie-Hellman parameter file that nginx can use'
	@[ -e $@ ] || openssl dhparam -out $@ 2048



# NOTE: SERVER is named in config file
#       It is the VPS server host that can be connected to via ssh
#       and will be
#       Host {name} defined in
#       gf: ~/.ssh/config
#       A distro upgrade will destroy /etc/letsencrypt
#       on local dev use sudo to remake and set permissions for dir
#       then secure copy certs from remote

certInit: /etc/letsencrypt/dh-param.pem

certRenew:
	@echo "renew my certs"
	@$(T)/certbot/certbot-auto certonly
	@$(MAKE) ngReload:

certConfig: /etc/letsencrypt/cli.ini


dhParam: /etc/letsencrypt/dh-param.pem


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
	@scp $(ACCESS_TOKEN) $(SERVER):~/$(GIT_USER)
