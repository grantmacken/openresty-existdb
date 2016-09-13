# openresty-existdb

 A TLS setup for openresty/nginx as reverse proxy for eXistdb

This repo is based on a previous one grantmacken/nginx-exist

I wanted to 
 - enable HTTPS by default
 - explore openresty/lua middleware capability

### Make Targets

`make ngDH`
 - creates the 1024 bit Diffie-Hellman Parameter 

`make ngCnf`
 - the main nginx.conf is generated 
 - src files and folders are symlinked to '/usr/local/openresty'  using `stow`

## src dirs/files in this repo

---
- openresty
  - nginx
    - conf: user created nginx 'include' conf files
            plus the main nginx.conf file which is generated with `make ngCfg`
    - ssl:  the dh-param.pem file generated via `make ngDH`
  - site
    - lualib: user created lua files
              Placing lua files here places in lau scripts in 'package.path'
              foo.lua + and bar.lua from https://openresty.org/en/using-luarocks.html 
              are here to check if luarocks is working ok
---

# Luarocks

  TODO!

