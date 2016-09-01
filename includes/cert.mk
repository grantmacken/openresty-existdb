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

# https://certbot.eff.org/docs/using.html#command-line
# This is an example of the kind of things you can do in a configuration file.
# All flags used by the client can be configured here. Run Certbot with
# "--help" to learn more about the available options.

########################################################################
# https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices
# using RSA keys stronger than 2,048 bits  and ECDSA keys stronger than
# 256 bits is a waste of CPU power and might impair user experience
########################################################################

rsa-key-size = 2048

# Uncomment and update to register with the specified e-mail address
email = grantmacken@gmail.com

# Uncomment and update to generate certificates for the specified
# domains.
domains = $(DOMAIN), www.$(DOMAIN)

# use a text interface instead of ncurses
text = true

# use the webroot authenticator. 
# set path to the default html dir 
authenticator = webroot
webroot-path = $(NGINX_HOME)/html

agree-tos = true

endef

certbotConf: export certbotConfig:=$(certbotConfig)
certbotConf:
	@echo "if they don't exist create dirs"
	@[ -d $(T)/certbot ] || mkdir $(T)/certbot
	@[ -d /etc/letsencrypt ] || mkdir /etc/letsencrypt
	@echo "create cli config file"
	@echo "$${certbotConfig}" > /etc/letsencrypt/cli.ini
	@[ -d $(T)/certbot/certbot-auto ] || curl https://dl.eff.org/certbot-auto -o $(T)/certbot/certbot-auto 
	@$(call chownToUser,$(T)/certbot/certbot-auto)
	@chmod +x $(T)/certbot/certbot-auto
	@$(T)/certbot/certbot-auto --help


