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

-------------------------------------------

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



