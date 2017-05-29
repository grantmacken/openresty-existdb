# eXist Install Target

```
make exInstall
make exClean
```
- exInstall :
 automated fetch and install of latest eXist version

- exClean : 
 this will stop the eXist service then mv the existing install into the backup dir
 
------------------------------------------------------------

Where we are heading for our remote production server:

 - Our eXist server is proxied behind OpenResty (nginx)
 - OpenResty is the public facing server
 - ufw fire-walls remote server and leaves 3 ports open to the world

    1. http:  port 80
    2. https: port 443
    3. ssh:   port 22

 - Any www traffic on port 80 will be redirected to the secure port 433
 - eXist (jetty) which serves on port 8080 will be closed to the world
 - Any authentication will be done using JWT Bearer tokens over HTTPS 
 - All access to eXist is controlled via OpenResty. If location access requires 
authorization then OpenResty will handle the Authorization, then make a request 
to eXist using Basic Auth, to access an eXist protected location or query the 
eXist server.

------------------------------------------------------------

mk-includes/ex-install.mk


