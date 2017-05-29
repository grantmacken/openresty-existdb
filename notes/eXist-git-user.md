
# Set up an alternate admin user 

This sets up eXist to use my configured git account user.name
with the password as my current GitHub access token.
The pathway to the token is set in the config file in the projects root

```
make exGitUserAdd
make exGitUserRemove
make exGitAdminCheck
```

[![asciicast](https://asciinema.org/a/103652.png)](https://asciinema.org/a/103652)

- eXGitAdminCheck: check who belongs to dba group
- exGitUserAdd:   set eXist to use my configured git account user.name and access token as password then check
- exGitUserRemove  remove eXist user and group

## Obtaining a access token

If you have a github account you can
 [obtain an access token](https://help.github.com/articles/creating-an-access-token-for-command-line-use/
)
 for commandline use, that allows you to authenticate, when using the github API.

My suggestion is to use this 'access token' as your main password for your new admin account.


### Original admin pass used by `make exInstall`

The dba group  account has 'admin' with the default user.
This is set when you install eXist.
The default install pass is admin, however if you have a 'access token' the install will use that.

note: The 'config' file contains a 'ACCESS_TOKEN_PATH' key.

To reiterate: if you place the 'access key' in the location indicated then 
 `make exInstall` will automatically use this as the headless install user admin password.


-------------------------------------------

## The use of git account user.name + github access token

Basic Authorization with eXist is user:password base64 combined.
We have set up an account with dba privileges using the
- user =  git account user.name
- pass = github access token

When starting OpenResty under systemd we make this 
user:password combo available as an ENVIROMENT variable.

```
 EXIST_AUTH=$(shell echo -n "$(GIT_USER):$(ACCESS_TOKEN)" | base64 )
```
This becomes our  base64 encoded string that can be used by openenresty for HTTP Basic Athentication with eXist

To use environment var 'EXIST_AUTH' in OpenResty, the env var must be set as a directive in nginx.conf

```
 env EXIST_AUTH;
```

Once set the environment var can be accessed use in lua modules to interact with eXist

``` 
local existAuth = os.getenv("EXIST_AUTH")
```
 
On the port 443 (HTTPS) we let OpenResty handle the process of Authentication and Authorisation 

Once Authorised, OpenResty can talk to eXist, using  Basic Authorization with  'os.getenv("EXIST_AUTH")',
to access protected eXist locations and eXist API calls

In this way OpenResty can act as access Authorization router gateway

```
asciinema rec demo.json -w 1 -t 'eXist git user' -c 'make --silent exGitUserTest'
asciinema play demo.json
asciinema upload demo.json
rm demo.json
```



