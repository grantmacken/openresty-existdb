
OpenResty nginx.conf and nginx-includes

```
ngInc
```
- ngInc:
  copies files from nginx-config  into openresty/nginx/conf
  the nginx-config directory contains our working conf includes.

#  generate nginx conf file on the fly then reload server

```
make ngBasic
make ngTLS
make ngDev
make ngProp
```

The above replaces the main nginx.conf file.

1. ngBasic: start with is and get your certs
2. ngTLS:   once you have your certs,
 use the check if to see if can the openresty server can serve your domain. It just serves welcome to openresty over https
 - should use SNI to serve multiple domains on one server 
 - should include reference modern SSL configuration
    - should redirect port 80 to port 443
    - should serve http2 
    - should use modern cyphers 
    - should use ... etc
    - etc TODO!
    - should run tests to prove above

3. ngDev : This is where we start app develpment.

file: mk-includes/ng-dev-conf.mk
 mk-includes/

 nginx-config/

1. ps aux | grep nginx


Once you have secured your site, its time to serve something usefull. To serve something usefull, you need a place to store data ... eXist a document datastore. You also need to be able to query the data store and transform results of a query into markup ... xQuery.

 We place OpenResty in front of eXist to behave as a 
 [reverse-proxy-server](https://www.nginx.com/resources/glossary/reverse-proxy-server/)


 When Nginx behaves as a reverse-proxy eXist, nginx will handle routing via nginx conf blocks
 It will translate request on port 433 to a request eXist on port 8080 
 e.g / proxied to /restxq/{domain}/home.html

This will be achieved by two conf blocks included in the nginx.conf created by `make ngDev`

1. rewrite blocks
2. location blocks

The nginx.conf created by `make ngDev` also handles, stuff which will be turned of on the prodction server

 - error.log set to debug `error_log logs/error.log debug;` 

note: `make orLoggedErrorFollow`
note:  `make orServiceLogFollow`

 - lua code cache  set to off  `lua_code_cache off;` 

4.  ngProd : this is production conf

#  conf includes outline
#   location level directives
#    routes
#      app-routes    [ for application routes ]
#      static-routes [ serving static files   ]
#      proxy-routes  [ configuring proxy locations ]
