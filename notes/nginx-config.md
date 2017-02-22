
OpenResty nginx.conf and nginx-includes

```
ngInc
make --silent ngBasic
ngTLS
```




 -ngInc:
  copies files from nginx-config  into openresty/nginx/conf
  the nginx-config directory contains our working conf includes.

The following replaces the main nginx.conf file.
The idea is to have a simple main conf with includes

- ngBasic: this is just serves on port 80
- ngTLS  : this is serves on port 443 80 



