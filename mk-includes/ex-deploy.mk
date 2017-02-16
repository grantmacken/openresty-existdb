
$(T)/download_url.txt:
	@echo "{{{## $(notdir $@) ##"
	@curl -s  https://api.github.com/repos/$(DEPLOY)/releases/latest | \
 jq '.assets[] | .browser_download_url'  >> $@
	@$(call chownToUser,$(@))
	@cat $@
	@echo '}}}'

# (: note pkgName is a string :)

$(T)/deploy.sh: $(T)/download_url.txt
	@echo "{{{## $(notdir $@) ##"
	@echo '#!/usr/bin/env bash' > $(@)
	@echo 'cd $(EXIST_HOME)' >> $(@)
	@echo "echo \"repo:install-and-deploy('$(REPO)','$(shell cat $<)')\" | \\" >> $@
	@echo ' java -jar $(EXIST_HOME)/start.jar client -sqx -u admin -P $(P) | tail -1' >> $@
	@$(call chownToUser,$(@))
	@chmod +x $(@)
	@cat $@
	@echo '}}}'

$(T)/undeploy.sh:
	@echo "{{{## $(notdir $@) ##"
	@echo '#!/usr/bin/env bash' > $(@)
	@echo 'cd $(EXIST_HOME)' >> $(@)
	@echo "echo \"repo:undeploy('$(REPO)')\" | \\" >> $@
	@echo ' java -jar $(EXIST_HOME)/start.jar client -sqx -u admin -P $(P) | tail -1' >> $@
	@$(call chownToUser,$(@))
	@chmod +x $(@)
	@cat $@
	@echo '}}}'

