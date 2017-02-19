
# Defining an eXist Service to run on boot


```
make --silent exService
make --silent exServiceRemove
```
1. exService :  create eXist.service in SYSTEMD PATH, enable and start and check if running by looking at the systemd journal log output, then view service state, whether port 8080 is open using nmap.  
2. exServiceRemove : stop and disable the service, then remove eXist.service in SYSTEMD PATH

running 'make exService' is pretty much all you need to do. The service should load on os boot, reboot etc.

In `mk-includes/ex-service` can redefine the systemd  eXist.service.
In the service I have added 
- an environment var
- working directory
- user and group 

The START_JAR also defines some -D vars that you can play with.

```
make --silent exServiceStop
make --silent exServiceStart
make --silent exServiceState
```
The above should be self evident.

When stopping or starting the service we follow the output of the systemd log. 
When the appropriate log entry is logged we know we have successfully stopped or started the service. Doing it this way we should get as graceful shutdown.

- exServiceState : should provide a view of the state of the service. It is called after you stop or start the service.

```
make exServiceStatus
make exServiceLog
Make exServiceLogFollow
```

- exServiceStatus :    just calls systemctl status  eXist.service
- exServiceLog :       view journalctl service log last 8 logged entries
- exServiceLogFollow : follow journalctl service log

--------------------------------------------------------------

make exLogger

note: when developing you can log to journald by calling

```
util:log-system-out("out you go")
```

