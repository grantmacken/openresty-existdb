<!--

-->

#eXist setup notes

Where we are heading for our remote production server:

 - Our eXist server is proxied behind OpenResty (nginx)
 - OpenResty is the public facing server-
 - ufw fire-walls remote server and leaves 3 ports open to the world

    1. http:  port 80
    2. https: port 443
    3. ssh:   port 22

 - Additionally any www traffic on port 80 will be redirected to the secure port 433.
 - eXist (jetty) which serves on port 8080 will be closed to the world
 - Any authentication will be done using JWT Bearer tokens over HTTPS 
 - All access to eXist is controlled via OpenResty. If location access is authorized then
 OpenResty will make a request to eXist using Basic Auth, to access an eXist protected location,
 or query the eXist server.

#Make setup targets

```
make exInstall
make exGhUser
make exSrv
make exStartService
```

1. make exInstall : fetch latest version and headless install of eXistDB
2. make exGhUser : set up main administrator user account
 - will add a new eXist user as your github user account owner name.  `git config --get user.name`
 - the new eXist user will use the `access token`
 - the new eXist user will belong to the DBA
3. make exSrv : establish eXistdb as a service under systemd


```
make exStop
make exStart
make exStatus
make exLog
```

```
make exRemoveService
make exLatestClean


```





# Main user account notes:

The main admin user account is 'admin' with the default user pass a admin.
If you have a github account you can obtain an access token for commandline use,
that allows you to authenticate, when using the github API.

https://help.github.com/articles/creating-an-access-token-for-command-line-use/

My suggestion is to use this 'access token' as your main password for the admin account.

The 'config' file contains a 'ACCESS_TOKEN_PATH' key.
If you place the 'access key' in the location indicated then 

1. `make exInstall` will automatically use this as the headless install user admin password.
2. `make exGhUser`

Basic Authorization with eXist is user:password base64 combined.
This sets up eXist to use my configured git account user.name
with the password as my current GitHub access token.
The pathway to the token is set in the config file in the projects root

Access to eXist is controlled via openresty.

When starting OpenResty under systemd we make available an ENVIROMENT variable.

```
 EXIST_AUTH=$(shell echo -n "$(GIT_USER):$(ACCESS_TOKEN)" | base64 )
```
This is a base64 encoded string that can be used by openenresty for HTTP Basic Athentication with eXist

To use enviroment var 'EXIST_AUTH' in OpenResty, the env var must be set as a directive in nginx.conf

    env EXIST_AUTH;

 Once set the enviroment var can be accessed use in lua modules to interact with eXist

    local existAuth = os.getenv("EXIST_AUTH")`

 OpenResty acts as access Authorization router gateway. 


