# openresty-existdb

 A TLS setup for openresty/nginx as reverse proxy for eXistdb

This repo is based on a previous one grantmacken/nginx-exist

I wanted to 
 - enable HTTPS by default
 - explore openresty/lua middleware capability

### Make:

`make ngDH`

`make ngCnf`
 - the main nginx.conf is generated 
 - src files and folders are symlinked to '/usr/local/openresty'  using Stow

## openresty/nginx configuration src dirs in this repo 

- openresty
  - nginx
    - conf : nginx conf files
    - ssl  : 

