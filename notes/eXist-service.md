
# Defining an eXist Service to run on boot

[![asciicast](https://asciinema.org/a/cx7v4u2nh84b34ad9ywsen2cb.png)](https://asciinema.org/a/cx7v4u2nh84b34ad9ywsen2cb)

```
make --silent exService
make --silent exServiceRemove
```
1. exService :  create eXist.service in SYSTEMD PATH, enable and start and check if running by looking at the systemd journal log output, then view service state, whether port 8080 is open using nmap.  
2. exServiceRemove : stop and disable the service, then remove eXist.service in SYSTEMD PATH

running 'make exService' is pretty much all you need to do. The service should load on os boot, reboot etc.


# Start, Stop, State Targets

```
make --silent exServiceStop
make --silent exServiceStart
make --silent exServiceState
```
The above should be self evident.

When stopping or starting the service we follow the output of the systemd log. 
When the appropriate log entry is logged we know we have successfully stopped 
or started the service. Doing it this way we should get as graceful shutdown.

- exServiceState : should provide a view of the state of the service. It is 
called after you stop or start the service. This call also uses nmap to see if 
port 8080 is open or closed

## Modifying Init Parameters

In `mk-includes/ex-service.mk` can redefine the systemd eXist.service.
In the service I have added 
- an environment var 'SERVER'
- working directory is set 
- user and group   eXist runs as Installer

Alter this if you need something differant

```
define eXistService
[Unit]
Description=The exist db application server
After=network.target

[Service]
Environment="EXIST_HOME=$(EXIST_HOME)"
$(if $(SUDO_USER),
Environment="SERVER=development",
Environment="SERVER=production")
WorkingDirectory=$(EXIST_HOME)
User=$(INSTALLER)
Group=$(INSTALLER)
ExecStart=$(START_JAR) jetty
ExecStop=$(START_JAR) shutdown -u admin -p $(P)

[Install]
WantedBy=multi-user.target
endef
```

Also the START_JAR also defines some -D vars that you can play with.

```
JAVA := $(shell which java)

START_JAR := $(JAVA) \
 -Dexist.home=$(EXIST_HOME) \
 -Djetty.home=$(EXIST_HOME)/tools/jetty \
 -Dfile.encoding=UTF-8 \
 -Djava.endorsed.dirs=$(EXIST_HOME)/lib/endorsed \
 -Djava.awt.headless=true \
 -jar $(EXIST_HOME)/start.jar
```

##  Service Status and journalctl Service Logs

```
make exServiceStatus
make exServiceLog
Make exServiceLogFollow
```

- exServiceStatus :    just calls systemctl status  eXist.service
- exServiceLog :       view journalctl service log last 8 logged entries
- exServiceLogFollow : follow journalctl service log

--------------------------------------------------------------

## Developing Using  exServiceLogFollow 

When developing you can log to journald by calling in a xQuery script

```
util:log-system-out("out you go")
```

In a open terminal you can follow the output by using `sudo make exServiceLogFollow`
I do this in tmux in a split window

`make exServiceLogFollowTest` : you should see  the log entry

```
asciinema rec demo.json -w 1 -t 'eXist systemd service'
asciinema play demo.json
asciinema upload demo.json && rm demo.json
```
