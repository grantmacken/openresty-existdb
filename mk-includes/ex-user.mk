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

CLIENT := java -jar $(EXIST_HOME)/start.jar client -sqx -u admin -P $(P) | tail -1

exUserExists = $(shell cd $(EXIST_HOME) && echo 'sm:user-exists("$1")' | $(CLIENT))

exGroupExists = $(shell cd $(EXIST_HOME) && echo 'sm:group-exists("$1")'  | $(CLIENT))

exUserAccountEnabled = $(shell cd $(EXIST_HOME) && echo 'sm:is-account-enabled("$1")' | $(CLIENT))

exIsDBA = $(shell cd $(EXIST_HOME) && echo 'sm:is-dba("$1")'  | $(CLIENT))

exPrimaryGroup = $(shell cd $(EXIST_HOME) && echo 'sm:get-user-primary-group("$1")' |\
 java -jar $(EXIST_HOME)/start.jar client -sqx -u admin -P $(P) | \
 tail -1)

exGroups = $(shell cd $(EXIST_HOME) && echo 'string-join((sm:get-user-groups("$1")),", ")' | $(CLIENT))

exGroupMembers = $(shell cd $(EXIST_HOME) && echo 'string-join((sm:get-group-members("$1")),", ")' | $(CLIENT))

exCreateAccount = $(shell cd $(EXIST_HOME) && echo 'sm:create-account("$1","$2","$3")'  | $(CLIENT))

exRemoveAccount = $(shell cd $(EXIST_HOME) && echo 'sm:remove-account("$1")'  | $(CLIENT))

exRemoveGroup = $(shell cd $(EXIST_HOME) && echo 'sm:remove-group("$1")' | $(CLIENT))

exRemoveGroupMember = $(shell cd $(EXIST_HOME) && echo 'sm:remove-group-member("$1","$2")'  | $(CLIENT))

exLogOut = $(shell cd $(EXIST_HOME) && echo 'util:log-system-out("$(1)")' | $(CLIENT))

exGitAdminCheck:
	@echo "admin groups: $(call exGroups,admin)"
	@echo "dba group members: $(call exGroupMembers,dba)"

exGitUserCheck:
	@echo "$(GIT_USER) is eXist user: $(call exUserExists,$(GIT_USER))"
	@echo "$(GIT_USER) is eXist group: $(call exGroupExists,$(GIT_USER))"
	@echo "$(GIT_USER) user account enabled : $(call exUserAccountEnabled,$(GIT_USER))"
	@echo "$(GIT_USER) user is dba : $(call exIsDBA,$(GIT_USER))"
	@echo "$(GIT_USER) user primary group : $(call exPrimaryGroup,$(GIT_USER))"
	@echo "$(GIT_USER) user groups: $(call exGroups,$(GIT_USER))"

exGitUserRemove:
	@echo "$(GIT_USER) is eXist user: $(call exUserExists,$(GIT_USER))"
	@echo "$(GIT_USER) is eXist group: $(call exGroupExists,$(GIT_USER))"
	@$(if $(findstring true,$(call exUserExists,$(GIT_USER))), \
 cd  $(EXIST_HOME) && echo 'sm:remove-group("$(GIT_USER)")' | $(CLIENT),)
	@$(if $(findstring true,$(call exUserExists,$(GIT_USER))), \
 cd $(EXIST_HOME) && echo 'sm:remove-account("$(GIT_USER)")' | $(CLIENT),)
	@$(MAKE) exGitAdminCheck
	@echo "$(GIT_USER) is eXist user: $(call exUserExists,$(GIT_USER))"
	@echo "$(GIT_USER) is eXist group: $(call exGroupExists,$(GIT_USER))"

exGitUserAdd:
	$(if $(ACCESS_TOKEN),true,false)
	@$(if $(findstring false,$(call exUserExists,$(GIT_USER))), \
 cd $(EXIST_HOME) && echo 'sm:create-account("$(GIT_USER)","$(P)","dba")' | $(CLIENT) , echo 'already user' )
	@$(if $(findstring true,$(call exUserExists,$(GIT_USER))),$(MAKE) exGitUserCheck, )
	@$(MAKE) exGitAdminCheck





exLogger:
	$(if $(ACCESS_TOKEN),true,false)
	@$(if $(findstring true,$(call exUserExists,$(GIT_USER))), echo 'ok', echo 'xx')

# @echo "$(call exLogOut, hi)"
