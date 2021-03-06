
$(T)/davfs2-latest.version:
	@echo "## $(notdir $@) ##"
	@echo 'fetch the latest davfs2 version '
	@echo $$( curl -s -L http://download.savannah.gnu.org/releases/davfs2/  |\
 tr -d '\n\r' |\
 grep -oP 'davfs2-([0-9]+\.){2}[0-9]+\.tar.gz' |\
 tail -1) > $(@)
	@echo "$(call cat,$(@))"

dlDavfs2: $(T)/davfs2-latest.version
	@echo "$(T)/$(call cat,$(<))" | sed s/\.tar\.gz//g 
	@[ -d  $$(echo "$(T)/$(call cat,$(<))" | sed s/\.tar\.gz//g)  ] || \
 curl -L http://download.savannah.gnu.org/releases/davfs2/$(call cat,$(<)) | \
 tar xz --directory $(T)
	cd  "$$(echo '$(T)/$(call cat,$(<))' | sed s/\.tar\.gz//g )" && \
 ./configure && make && sudo make install
# echo '------------------------------------------------'

$(T)/webdav.log:
	@echo '## $(notdir $@) ##'
	@$(call assert-is-root)
	@$(info CHECK -  mount.davfs suid flag set for user, allowing user to mount webdav)
	@test -u /usr/sbin/mount.davfs || \
 $(shell which expect) -c "spawn dpkg-reconfigure davfs2 -freadline; expect \"Should\"; send \"y\\n\"; interact" 
	@$(info CHECK -  if there is a davfs group )
	@$(if $(shell echo "$$(groups davfs2 2>/dev/null)"),\
 $(info OK! there is davfs2 group),\
 groupadd davfs2 && usermod -aG davfs2 $(SUDO_USER) && groups davfs2 )
	@$(info CHECK -  if user belongs to davfs2 group )
	@$(if $(shell echo "$$(id $(SUDO_USER) 2>/dev/null | grep -oP '(\Kdavfs2)')"),\
 $(info OK! user belongs to davfs2 group),\
 usermod -aG davfs2 $(SUDO_USER) && echo 'Need to refresh group membership by *logging out* ' )
	@$(info CHECK -   have $(HOME)/eXist davfs mount point in fstab)
	@$(if $(shell echo "$$(cat /etc/fstab | grep $(HOME)/eXist )"),\
 $(info OK! have davfs mount point in fstab),\
 echo "http://localhost:8080/exist/webdav/db  $(HOME)/eXist  _netdev,user,rw,noauto  0  0" >> /etc/fstab )
	@$(if $(shell echo "$$( mount | grep -oP '$(HOME)/eXist' )"),\
  umount $(HOME)/eXist,\
 $(info not yet mounted))
	@echo '#very very very secret' >  /etc/davfs2/secrets
	@echo '/home/$(SUDO_USER)/eXist admin  $(P)' >> /etc/davfs2/secrets
	@chmod -v 600 /etc/davfs2/secrets
	@if [ ! -d $(HOME)/eXist ] ; then mkdir $(HOME)/eXist ; fi
	@if [ ! -d $(HOME)/.davfs2 ] ; then mkdir $(HOME)/.davfs2 ; fi
	@cp /etc/davfs2/davfs2.conf $(HOME)/.davfs2/davfs2.conf
	@cp /etc/davfs2/secrets $(HOME)/.davfs2/secrets
	@chown -v $(SUDO_USER):davfs2 $(HOME)/.davfs2/*
	su -c "mount $(HOME)/eXist" -s /bin/sh $(INSTALLER)
	@echo '-------------------------------------------------'

