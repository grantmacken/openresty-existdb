#
# DOMAIN located in config
#
# @description: when working with local dev server, change hosts file
#
# #####################################################################

hostsRemote:
	@cat /etc/hosts | grep $(DOMAIN) >/dev/null || \
 echo '$(shell dig @8.8.8.8 +short $(DOMAIN))  $(DOMAIN)' >> /etc/hosts
	@sed -i "/$(DOMAIN)/ s/.*/$(shell dig @8.8.8.8 +short $(DOMAIN))\t$(DOMAIN)/g" /etc/hosts
	@cat /etc/hosts | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}\s+\S+'
	nmap $(shell dig @8.8.8.8 +short $(DOMAIN))

# @curl -L -s -o /dev/null -w\
# "\n\tHTTP CODE:\t%{http_code}\n\tHTTP_VERSION:\t%{http_version}\n\tREMOTE_IP:\t%{remote_ip}\n\tLOCAL_IP:\t%{local_ip}\n"\
# http://$(DOMAIN)
# @curl -L -s -o /dev/null -w "\n\tSSL VERIFY RESULT:\t%{ssl_verify_result}\n" https://$(DOMAIN)
# @w3m -dump $(DOMAIN)

hostsLocal:
	@cat /etc/hosts | grep $(DOMAIN) >/dev/null || echo '127.0.0.1  $(DOMAIN)' >> /etc/hosts
	@sed -i "/$(DOMAIN)/ s/.*/127.0.0.1\t$(DOMAIN)/g" /etc/hosts
	@cat /etc/hosts | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}\s+\S+'
	@nmap $(DOMAIN)
	@curl -L -s -o /dev/null -w\
 "\n\tHTTP CODE:\t%{http_code}\n\tHTTP_VERSION:\t%{http_version}\n\tREMOTE_IP:\t%{remote_ip}\n\tLOCAL_IP:\t%{local_ip}\n"\
  http://$(DOMAIN)
	@w3m -dump $(DOMAIN)
	@w3m -dump https:/$(DOMAIN)

wwwDump:
	w3m -dump https://$(DOMAIN)

wwwDumpHead:
	w3m -dump_head $(DOMAIN)

wwwInfo:
	@curl -L -s -o /dev/null -w\
 "\n\tHTTP CODE:\t%{http_code}\n\tHTTP_VERSION:\t%{http_version}"\
 "\tREMOTE_IP:\t%{remote_ip}\n\tLOCAL_IP:\t%{local_ip}\n"\
 https://$(DOMAIN)

wwwResponse:
	@curl -s -w '\nLookup time:\t%{time_namelookup}\nConnect time:\t%{time_connect}\nPreXfer time:\t%{time_pretransfer}\nStartXfer time:\t%{time_starttransfer}\n\nTotal time:\t%{time_total}\n' -o /dev/null http://$(DOMAIN)
	@curl -s -w '\nLookup time:\t%{time_namelookup}\nConnect time:\t%{time_connect}\nAppCon time:\t%{time_appconnect}\nRedirect time:\t%{time_redirect}\nPreXfer time:\t%{time_pretransfer}\nStartXfer time:\t%{time_starttransfer}\n\nTotal time:\t%{time_total}\n' -o /dev/null $(DOMAIN)

hostsExternalIP:
	@curl icanhazip.com

