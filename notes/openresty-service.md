
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
sudo make orServiceLogFollow
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

## Using Systemd Enviroment var to talk to backend server

The same method can be used for any backend server ( eXist, redis, etc. )
 - Place OpenResty in front of the backend server. 
 - Set an Environment var in Systend service file   [ `Environment="API_KEY=keyValue"` ]
 - Capture the var in nginx.conf directive. [ ` env API_KEY;` ]
 - Use in lua block [ os.getenv("API_KEY")';] to talk to backend

For eXist we create 2 Environment Vars 

1. `OPENRESTY HOME`  file path to openresty
2. `EXIST_AUTH`       basic access authentication for exist dba

```
Environment="OPENRESTY_HOME=$(OPENRESTY_HOME)"
Environment="EXIST_AUTH=$(shell echo -n "$(GIT_USER):$(ACCESS_TOKEN)" | base64 )" 
```

In our final setup eXist is proxied behind OpenResty. Access control will be 
done by OpenResty (JWT tokens over https). Only If Authorised by OpenResty, 
then OpenResty will use Basic Authorization provided in the Enviroment var to 
access eXist.


## define OpenResty Service

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
