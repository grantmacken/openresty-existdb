#
# set permissions on www folders
# group add nginx
# useradd --comment 'Nginx' --shell /bin/false --home /dev/null -g nginx  nginx
# useradd --comment 'Nginx' --shell /bin/false --home /dev/null nginx
# id nginx
# sudo find . -type f -exec chmod 664 {} +
# sudo find . -type d -exec chmod 775 {} +
#
#################################

orPerms:
	echo $(SUDO_USER)
	usermod -d $(OPENRESTY_HOME)/nginx/html nobody
	usermod -a -G $(SUDO_USER) nobody
	chgrp -R $(SUDO_USER) $(OPENRESTY_HOME)/nginx/html
	chmod -R g+w $(OPENRESTY_HOME)/nginx/html
	chmod g+s $(OPENRESTY_HOME)/nginx/html
	@ls -al $(OPENRESTY_HOME)/nginx/html 
	@cd $(OPENRESTY_HOME)/nginx/html && find . -type d -exec chmod 775 {} +
	@cd $(OPENRESTY_HOME)/nginx/html && find . -type f -exec chmod 664 {} +
	@ls -al $(OPENRESTY_HOME)/nginx/html 
