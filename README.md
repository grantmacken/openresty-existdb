# openresty-existdb

 A TLS setup for openresty/nginx as reverse proxy for eXistdb

This repo is based on a previous one grantmacken/nginx-exist

I wanted to 
 - enable HTTPS by default
 - explore openresty/lua middleware capability

## Openresty

I want to automate the install of the latest openresty,
with ssl enabled

### `make dl`

Check for latest versions of
 -  openresty
 -  pcre
 -  openssl
 -  zlib

and download newest version

### `make orInstall`

with latest versions compile and install openresty

check the configure directives first

### `make orService 

This installs openresty as a systemd init service

Note: system environment variables
  OPENRESTY HOME  file path to openresty
  EXIST_AUTH      basic access authentication for exist admin account-
  this is a base64 encoded string that can  be used for HTTP Basic Athentication  with eXistdb proxied behind nginx

  Any OpenResty auth will be done using JWT Bearer tokens over HTTPS 
  Openresty acts a access Authorization router gateway so when access is authorized by OpenResty then use Basic Auth to access the eXist protected location. 

 @see  https://tools.ietf.org/html/rfc2617

 The env var must be set as a directive in nginx.conf
 env EXIST_AUTH;

 Once set the enviroment var can be accessed use in lua modules to interact with eXist

`local existAuth = os.getenv("EXIST_AUTH")`

Basic Authorization with eXist is user:password base64 combined.
I have setup eXist to use my configured git account user.name
with the password as my current GitHub access token. The pathway to the token is set in the config file in the projects root. 



## Openresty Package Management

The next version of openresty will use its own package manager,
 in the meantime use luarocks

note luajit version is hardwired

`make luarocksLatest`
 -  downloads latest version

`make luarocksInstall`
  - installs latest version

`make rocks` 
  - install some rocks

## Setting Up Serving HTTPS by default


`make ngDH` 
 - creates the 1024 bit Diffie-Hellman Parameter 

TODO!

 
### Development Make Targets

`make lua-module` and `make watch-lua-modules`

* src lua module files are copied to '/usr/local/openresty/site/lualib/mod'

`make nginx-config` and `make watch-nginx-config`

* src nginx conf file  are copied to '/usr/local/openresty/nginx/conf'

`make orDev`

- Run this when 
1. changes are made to src files in 'openresty/nginx/conf/' or
2. changes made to the dynamicaly generated 'nginx.conf' in the make file 'includes/nginx-conf.mk' or
3. new src lua files are added to 'openresty/site/lualib/lib'
 
When`make orDev` is run  
1. the development nginx.conf is generated by `make` and placed directly into
   `/usr/local/openresty/nginx/conf/` 
2. src files in the nginx-config file are copied to the nginx conf folder
3. as sudo the main 'ngnix.conf' is tested and reloaded

NOTES: The nginx.conf generated by  orDev will add the directive `lua_code_cache off;`.  With this off any changes to
lua scripts will not require a nginx reload.
