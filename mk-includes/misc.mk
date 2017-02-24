
$(T)/luarocks-latest.version: $(T)/luarocks-previous.version
	@echo "{{{ $(notdir $@) "
	@echo 'fetch the latest luarocks version'
	@cp -f $@ $(<)
	@echo $$( curl -s -L  http://keplerproject.github.io/luarocks/releases/ | tr -d '\n\r' |\
 grep -oP 'luarocks-\K([0-9\.]+)(?=\.tar\.gz)' |\
 head -1) > $(@)
	@[ "$$(<$@)" = "$$(<$(<))" ]  || $(MAKE) downloadLuarocks
	@touch  $(<)


downloadLuarocks: $(T)/luarocks-latest.version
	@echo 'download the latest  version'
	@echo  "$$(<$(<))" 
	curl -L http://keplerproject.github.io/luarocks/releases/luarocks-$(shell echo "$$(<$<)").tar.gz | tar xz --directory $(T)
	@echo '------------------------------------------------'

# orPaths: 
# @echo 'pre luarocks'
# @export PATH=$(OPENRESTY_HOME)/bin:$$PATH
# @export PATH=$(OPENRESTY_HOME)/luajit/bin:$$PATH
# @cd $(OPENRESTY_HOME)/luajit/bin; ln -s luajit lua


luaJitVer =  $(shell echo "$$(luajit -v | grep -oP 'LuaJIT\s\K(\S+)')")

lrInstall:
	@echo 'install luarocks version'
	@echo $(luarocksVer)
	@cd $(T)/luarocks-$(luarocksVer) && \
./configure \
--prefix=$(OPENRESTY_HOME)/luajit \
--with-lua=$(OPENRESTY_HOME)/luajit \
--lua-suffix=jit-2.1.0-beta2 \
--with-lua-include=$(OPENRESTY_HOME)/luajit/include/luajit-2.1 && make && make install
	@echo '--------------------------------------------'


rocks:
	@luarocks list 'xml' | grep 'xml' && luarocks show 'xml' || luarocks install 'xml' 
	@luarocks list 'net-url' | grep 'net-url' && luarocks show 'net-url' || luarocks install 'net-url' 
	@luarocks list 

downloadSiege:
	@echo 'download the latest siege version'
	@curl http://download.joedog.org/siege/siege-latest.tar.gz | \
tar xz --directory $(T)
	@echo '------------------------------------------------'
# cd $(T)/redis-stable; $(MAKE) && $(MAKE) test && $(MAKE) install
# REDIS
########################################################################

downloadRedis:
	@echo 'download the stable redis version'
	curl http://download.redis.io/redis-stable.tar.gz | \
tar xz --directory $(T)
	cd $(T)/redis-stable; $(MAKE) && $(MAKE) test && $(MAKE) install
	@echo '------------------------------------------------'


# change redis config
# daemonize no > daemonize yes 
# supervised no > supervised systemd
# dir ./ > /var/lib/redis

initRedis:
	@$(call assert-is-root)
	@$(call assert-is-systemd)
	@echo 'configure redis'
	@adduser --system --group --no-create-home redis
	@mkdir /var/lib/redis
	@chown redis:redis /var/lib/redis
	@chmod 770 /var/lib/redis

rdsConf:
	@mkdir -p $(OPENRESTY_HOME)/site/redis
	@mkdir -p openresty/site/redis/conf
	@mkdir -p openresty/site/redis/logs
	@cp $(T)/redis-stable/redis.conf openresty/site/redis/conf/redis.conf
	@sed -i 's/supervised no/supervised systemd/g' openresty/site/redis/conf/redis.conf
	@sed -i 's%pidfile /var/run/redis_6379\.pid%pidfile ./logs/redis.pid%g' openresty/site/redis/conf/redis.conf
	@$(MAKE) stow

# @sed -i 's%dir \./%dir /var/lib/redis%g' openresty/redis/conf/redis.conf
# @sed -i 's/daemonize no/daemonize yes/g' openresty/redis/redis.conf

define redisService
[Unit]
Description=Redis In-Memory Data Store
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
WorkingDirectory=$(OPENRESTY_HOME)/site/redis
PIDFile=$(OPENRESTY_HOME)/site/redis/logs/redis.pid

ExecStart=/usr/local/bin/redis-server $(OPENRESTY_HOME)/site/redis/conf/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
ExecReload=/bin/kill -USR2 $$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
endef


rdsService: export redisService:=$(redisService)
rdsService:
	@echo "setup redisService as redis.service under systemd"
	@$(call assert-is-root)
	@$(call assert-is-systemd)
	@echo 'Check if service is enabled'
	@echo "$(systemctl is-enabled redis.service)"
	@echo 'Check if service is active'
	@systemctl is-active redis.service && systemctl stop  redis.service || echo 'inactive'
	@echo "$${redisService}"
	@echo "$${redisService}" > /lib/systemd/system/redis.service
	@systemd-analyze verify redis.service
	@systemctl is-enabled redis.service || systemctl enable redis.service &&  echo 'redis service enabled'
	@systemctl start redis.service
	@echo 'Check if service is enabled'
	@systemctl is-enabled redis.service
	@echo 'Check if service is active'
	@systemctl is-active redis.service
	@echo 'Check if service is failed'
	@systemctl is-failed redis.service || echo 'OK!'
	@journalctl -u redis.service -o cat
	@echo '--------------------------------------------------------------'

#@echo 'Check if service is failed'
#@systemctl is-failed redis.service || systemctl stop redis.service && echo 'inactive'
