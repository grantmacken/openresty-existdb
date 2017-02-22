
# Defining an OpenResty systemd service to load on boot

```
sudo make orService
sudo make orServiceRemove
```
-  orService :  create eXist.service in SYSTEMD PATH, enable and start and 
check if running by looking at the systemd journal log output, then view 
service state, whether port 80 and 433 is open using nmap.  
-  orServiceRemove : stop and disable the service, then remove 
openresty.service in SYSTEMD PATH


# Start, Stop, State and Log Targets

```
sudo make orServiceStop
sudo make orServiceStart
sudo make orServiceStartDev
make orServiceState
sudo make orServiceLog
make orServiceStatus
make orLoggedErrors
make orLoggedErrorFollow
```

Most of the above should be self evident

When developing website  you might want to follow the nginx error log
so `make orLoggedErrorFollow` or ```sudo make orServiceStartDev``
which will start the service and start the log.

If you want to see all errors, make sure your ngnix.conf error log is set to debug 

```
# Note: error log with debug used during development
error_log logs/error.log debug;
pid       logs/nginx.pid;
```
## Defining The Service

The service is defined in `mk-includes/or-service.mk`

Of Note: 
We create 2 Environment Vars 

1. OPENRESTY HOME  file path to openresty
2. EXIST_AUTH      basic access authentication for exist dba

In our final setup eXist is proxied behind OpenResty

Access control will be done by OpenResty (JWT tokens over https)
If authorised then OpenResty can use Basic Authorisation to access the eXist protected locations or make APIs  calls

```
Environment="OPENRESTY_HOME=$(OPENRESTY_HOME)"
Environment="EXIST_AUTH=$(shell echo -n "$(GIT_USER):$(ACCESS_TOKEN)" | base64 )" 
```

this is a base64 encoded string that can  be used for HTTP Basic Athentication 
with openrestydb proxied behind openresty
Any Nginx auth will be done using JWT Bearer tokens over HTTPS
  if Authorised then
  use Basic Auth to access openresty protected location

```
define openrestyService
[Unit]
Description=OpenResty stack for Nginx HTTP server
After=network.target

[Service]
Type=forking
Environment="OPENRESTY_HOME=$(OPENRESTY_HOME)"
Environment="EXIST_AUTH=$(shell echo -n "$(GIT_USER):$(ACCESS_TOKEN)" | base64 )"
WorkingDirectory=$(OPENRESTY_HOME)
PIDFile=$(OPENRESTY_HOME)/nginx/logs/nginx.pid
ExecStartPre=$(OPENRESTY_HOME)/bin/openresty -t
ExecStart=$(OPENRESTY_HOME)/bin/openresty
ExecReload=/bin/kill -s HUP $$MAINPID
ExecStop=/bin/kill -s QUIT $$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
endef
```
