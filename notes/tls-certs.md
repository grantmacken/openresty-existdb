```
make certInit
make certRenew
make certConfig
```
- certInit
 - creates a configuration file.
 - This downloads and install certbot 
 - creates a  Diffie-Hellman parameter file
 
- certRenew 
 - This renews the certs
 - Restarts openresty so it can pick up the renewed certs

- certConfig 
 - This remakes the command line ini file that certbot uses. It saves it to the 
default dir ```/etc/letsencrypt```

The certbot cli.ini is defined in ```mk-includes/or-certs.mk``` , it should work as is, but feel free to alter as you see fit.

```
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
```

## Web Root Path

The most important bit is the web-root-path

For this to work, you must have
- port 80 open,
- a nginx.conf root defined location 
 ```$(OPENRESTY_HOME)/nginx/html```
-  an associated  nginx conf port 80 include server block 

```
#  HTTP server
server {
  root html;
  index index.html;
  listen 80 default_server;
  listen [::]:80 default_server;

  server_name ~^(www\.)?(?<domain>.+)$;

  # Endpoint used for performing domain verification with Let's Encrypt.
  location /.well-known/acme-challenge {
    default_type "text/plain";
    allow all;
  }
 # Redirect all HTTP requests to HTTPS with a 301 Moved Permanently response.
  location / {
     return 301 https://$http_host$request_uri;
     }
}
```

TODO! ref to nginx configuration section


### Adding and Removing Domains
 If you add domains to the config file 


```
DOMAINS=gmack.nz www.gmack.nz
 ```
 
Then `make certConfig will generate a new ini file that will be used by certbot. 
 
 ```
domains = $(MY_DOMAINS)
 ```

the full set of ini options are in the
[certbot docs]( https://certbot.eff.org/docs/using.html#command-line)

### RSA key size:

```
rsa-key-size = 2048
```

We leave to RSA key size to 2048 as suggested by 
[ssllaabs SSL-and-TLS-Deployment-Best-Practices](https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices) 


    using RSA keys stronger than 2,048 bits  and ECDSA keys stronger than 256 bits 
    is a waste of CPU power and might impair user experience


 https://www.ssllabs.com/ssltest/analyze.html?d=gmack.nz
 https://certlogik.com/ssl-checker/gmack.nz/summary
 https://certlogik.com/ssl-checker/gmack.nz
 https://observatory.mozilla.org/analyze.html?host=gmack.nz
 https://tls.imirhil.fr/https/gmack.nz
