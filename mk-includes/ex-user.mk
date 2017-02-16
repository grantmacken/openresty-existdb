#
# git-user-as-eXist-user
#
# requires a running instance of eXist
# usees the client jar
#
#
#
# ########################

.PHONY: git-user-as-eXist-user

exUserExists !=  cd $(EXIST_HOME) && echo 'sm:user-exists("$(GIT_USER)")' |\
 java -jar $(EXIST_HOME)/start.jar client -sqx -u admin -P $(P) | \
 tail -1

exUserAccountEnabled !=  cd $(EXIST_HOME) && echo 'sm:is-account-enabled("$(GIT_USER)")' |\
 java -jar $(EXIST_HOME)/start.jar client -sqx -u admin -P $(P) | \
 tail -1

exIsDBA !=  cd $(EXIST_HOME) && echo 'sm:is-dba("$(GIT_USER)")' |\
 java -jar $(EXIST_HOME)/start.jar client -sqx -u admin -P $(P) | \
 tail -1


ex-git-user-as-eXist-user:
	$(if $(ACCESS_TOKEN),\
 $(info 'found  github 'access token'),\
 $(error 'need to get a git-hub access token for this to work' ))
	@echo "USER: $(GIT_USER) is eXist user := $(exUserExists) "
	@echo "USER: $(GIT_USER) user account enabled := $(exUserAccountEnabled) "
	@echo "USER: $(GIT_USER) user is dba  := $(exIsDBA) "
	@$(if $(findstring true,$(exUserExists)),,\
 cd $(EXIST_HOME) && echo 'sm:create-account( "$(GIT_USER)", "$(P)", "dba" )' | \
 java -jar $(EXIST_HOME)/start.jar client -sqx -u admin -P $(P) | \
 tail -1)
