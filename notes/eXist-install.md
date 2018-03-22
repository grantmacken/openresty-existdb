# eXist Install Target

```
make exBuild
make exPass
make exClean
```
- exBuild: clones git repo and builds eXist in directory $(EXIST_HOME)
           When called again, this will pull changes from master and rebuild 

- exPass:  start eXist and set new username and password 

- exClean:  this will stop the eXist service then mv the existing install into the backup dir

------------------------------------------------------------

Notes: In the past I Izpack to install eXist which failed to install eXist.
Besides the Izpack bin is rather large. I now think a git pull, is the way 
to go.

After the initial clone, it is most likely easy to automate, the pull and build.

On the initial clone and build, the dba group account has 'admin' with the default user.
The initial build also has a empty 'admin' password.

`exInitRun` will start eXist and reset password to your 'github access token'

Next Up [](notes/eXist-service.md)

----------------------------------

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


