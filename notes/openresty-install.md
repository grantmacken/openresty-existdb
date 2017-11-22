
# OpenResty Install


Configure, 
Install and 
Check if we can start stop openResty

```
make orConfigure
make orInstall
make ngInit
```

Set up as a Systemd service 

sudo make orServiceStart
make ngClean
make ngBasic
```

 - ngClean:   clean up the nginx configuration dir
 - opmGet:    install some lualibs into the site/resty dir
 - orModules: install my WIP lua modules into the site/[git-user] dir 

make ngDev

 - ngDev:     Add my WIP nginx confiration files



Automates the OpenResty install 
 
Establishes latest version of sources,
then if required downloads the source archive.

- OpenResty
- zlib : zip library
- pcre : perl reg ex
- openssl 

Installs and compiles from latest sources.

the configurable OpenResty configure install options are in the target. 
`mk-includes/or-install.mk`.  Alter the configure options to fit your 
requirements. 






