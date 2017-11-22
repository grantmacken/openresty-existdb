# eXist user
# requires a running instance of eXist
# uses the client jar
# ########################
define exUserHelp
=========================================================
eXist USER: changing user account

  requires a runnning instance of eXist
  main focus is to use the eXist client jar
  to set up a user/group account based on
  - my git user name
  - my git user access token

==========================================================

`make exGitUserAddd`

endef

ClIENT_REPL := $(EXIST_HOME)/bin/client.sh -u admin -P $(ACCESS_TOKEN) -s

CLIENT := $(shell which java) -jar $(EXIST_HOME)/start.jar client -q -u admin -P $(ACCESS_TOKEN)


exUserExists = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'sm:user-exists("$1")' |  tail -n -1  )

exGroupExists = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'sm:group-exists("$1")'  |  tail -n -1 )

exUserAccountEnabled = $(shell cd $(EXIST_HOME) && $(CLIENT) -x  'sm:is-account-enabled("$1")' | tail -n -1 )

exIsDBA = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'sm:is-dba("$1")' | tail -n -1 )

exPrimaryGroup = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'sm:get-user-primary-group("$1")' )

exGroups = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'string-join((sm:get-user-groups("$1")),", ")' | tail -n -1 )

exGroupMembers = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'string-join((sm:get-group-members("$1")),", ")' | tail -n -1 )

exCreateAccount = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'sm:create-account("$1","$2","$3")' )

exRemoveAccount = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'sm:remove-account("$1")' | tail -n -1 )

exRemoveGroup = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'sm:remove-group("$1")' | tail -n -1 )

exRemoveGroupMember = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'sm:remove-group-member("$1","$2")'  | tail -n -1 )

exLogOut = $(shell cd $(EXIST_HOME) && $(CLIENT) -x 'util:log-system-out("$(1)")' | tail -n -1 )

exClient:
	@$(ClIENT_REPL)

exClientTest:
	@cd $(EXIST_HOME) && $(CLIENT)  -x 'util:uuid()' | tail -n -1

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
	@$(if $(findstring true,$(call exUserExists,$(GIT_USER))),$(call exRemoveAccount,$(GIT_USER)),)
	@$(if $(findstring true,$(call exGroupExists,$(GIT_USER))),$(call exRemoveGroup,$(GIT_USER)),)
	@$(MAKE) --silent exGitAdminCheck

exGitUserAdd:
	$(if $(ACCESS_TOKEN),true,false)
	@echo $(ACCESS_TOKEN)
	@$(if $(findstring false,$(call exUserExists,$(GIT_USER))),\
  cd $(EXIST_HOME) && $(CLIENT) -x 'sm:create-account("$(GIT_USER)","$(ACCESS_TOKEN)","dba")' ,\
 echo 'already user')
	@$(MAKE) --silent exGitUserCheck
#@$(MAKE) --silent exGitAdminCheck

exGitUserTest:
	@echo 'check who belongs to dba group '
	@$(MAKE) --silent exGitAdminCheck
	@echo 'set eXist to use my configured git account user.name and access'
	@echo ' token as password then check'
	@$(MAKE) -- silent exGitUserAdd
	@echo 'remove eXist user and group'
	@$(MAKE) exGitUserRemove

