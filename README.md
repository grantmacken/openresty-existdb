# openresty-existdb

 A TLS setup for openresty/nginx as reverse proxy for eXistdb

This repo is based on a previous one grantmacken/nginx-exist

I wanted to 
 - enable HTTPS by default
 - explore openresty/lua middleware capability

# How to use

The repo was designed to be used on a production VPS 
or local development environment.

It assumes you 
1. own you own domains and 2. 
2. set git with configured global user.name and user.email
 -  `git config --global user.name` 
 -  `git config --global user.email`
3. have your own github account and obtained github access token that can be used on the commandline

[setting-your-username-in-git]( https://help.github.com/articles/setting-your-username-in-git/)
 

## steps

1. Create a dir structure following your github owner account.
`mkdir -p ~/projects/$(git config --global user.name)`

2. create your github access token file and place github token in it.
 -  `touch  ~/projects/$(git config --global user.name)/.access.token`
 - [Get a github token](https://help.github.com/articles/creating-an-access-token-for-command-line-use/) and place in above file.
 - WARNING!! do not place the containing 'owner' folder or a  place access token file under git control. 

3. cd into the owner folder and clone this project 
 - `cd  ~/projects/$(git config --global user.name) && git clone gitt@github.com:grantmacken/openresty-existdb.git`

4. take a look at the config file
   The key values you can change are 
    - DEPLOY : {OWNER/DOMAIN} the github repo of the development website you can deploy
    - DOMAIN : a list of domains you want hosted on server
    - SERVER : the ssh host

## OPENRESTY  Install and Configure

1. `make or`       :  gets latest src files and compiles and installs openresty
                      plus creates nginx conf files
                      plus creates a Diffie-Hellman pameter file
                      plus copies over my wip lua modules
2. `make opmGet`   :  installs some opm packages
3. `make lrInstall`:  installs luarocks (temp until opm takes over)
4. `make rocks`    :  installs rocks ( lua packages not avaiable to opm ) 
5. `make orClean`  :  just removes the openresty dir

## Only On Remote Production Server Get SSL Certs For Your Domains

If you have not got any certs from letsencrypt

1. `make cnfPort80`
 - basic nginx conf for getting certs from letsencypt

Then get certbot auto and setup the bots config

1. `make certbotConf` :
 - do once or if you make changes to conf e.g. add more domains
 - downloads cerbot auto
 - creates the certbot configuration file
2. `make certbotRenew`
 - use to renew
 - uses the config to get certs from lets encrypt





## Only On Local Development Server Copy Over Certs

1.  as sudo `make syncCertPerm`
 - set permissions
2.  `make syncCerts` 
 - copy over certs from remote

## Create a openresty systemd service

1. `make orService` 
 - installs openresty as a systemd init service

## Setting Up Serving HTTPS by default

1. `make orDev`
  - creates development nginx conf and places into nginx conf dir
2. `sudo systenctl stop openresty`
3. `sudo systenctl start openresty`
4. `sudo systenctl status openresty`


## Openresty Development Workfow

1. `make ngConf` on local development server use  `make watch-nginx-conf`
 - copy any any files in nginx-conf files over into openresty
 - development work mainly on
   - serverRewrite.conf
   - locationBlocks.conf
2. `make orReload` On local server run as sudo
 - test nginx conf and reload
3. `make lua-modules`  `make watch-lua-modules`
 - copy any files in lua-modules over into openresty
 - note: no need to nginx reload in dev enviroment

## Ready For Production

1. `make orProd`
  - creates production  nginx conf and places into nginx conf dir
2. `sudo systenctl stop openresty`
3. `sudo systenctl start openresty`
4. `sudo systenctl status openresty`

#NOTES:

## system environment variables

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




## Openresty automated install
I want to automate the install of the latest openresty,
with ssl enabled

Check for latest versions of
 -  openresty
 -  pcre
 -  openssl
 -  zlib

and download newest version

with latest versions compile and install openresty

check the configure directives first


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
