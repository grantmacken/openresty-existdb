
define ufwExist
[eXist]
title=eXist XML database
description=eXists is xml database in a jetty container listening on port 8080
ports=8080/tcp
endef

define ufwOpenSSH
[OpenSSH]
title=Secure shell server, an rshd replacement
description=OpenSSH is a free implementation of the Secure Shell protocol.
ports=22/tcp
endef

define ufwNginx
[Nginx]
title=Web Server (Nginx, HTTP + HTTPS)
description=Small, but very powerful and efficient web server
ports=80,443/tcp
endef

uwf:
	@$(MAKE) --silent /etc/ufw/applications.d/Nginx
	@$(MAKE) --silent /etc/ufw/applications.d/OpenSSH
	@$((MAKE) --silent /etc/ufw/applications.d/eXist
	@ufw reset
	@ufw app list
	@ufw app update Nginx
	@ufw app update eXist
	@ufw app update OpenSSH
	@ufw app list
	@ufw app info Nginx
	@ufw app info eXist
	@ufw app info OpenSSH
	@ufw app info OpenSSH
	@ufw status verbose
	@ufw default deny incoming
	@ufw default allow outgoing
	@ufw allow OpenSSH
	@ufw allow Nginx
	@ufw allow from 192.168.0.0/24
	@ufw enable
	@ufw status numbered


uwfClean:
	rm /etc/ufw/applications.d/*

/etc/ufw/applications.d/Nginx export ufwNginx:=$(ufwNginx)
/etc/ufw/applications.d/Nginx:
	@echo "$${ufwNginx}" > $@

/etc/ufw/applications.d/OpenSSH: export ufwOpenSSH:=$(ufwOpenSSH)
/etc/ufw/applications.d/OpenSSH:
	@echo "$${ufwOpenSSH}" > $@

/etc/ufw/applications.d/eXist: export ufwExist:=$(ufwExist)
/etc/ufw/applications.d/eXist:
	@echo "$${ufwExist}" > $@
