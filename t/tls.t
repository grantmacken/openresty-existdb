#!/usr/bin/env bash
source t/setup
use Test::More

plan tests 9

note " TLS Test Plan"
note "==============="
note "OWNER : $OWNER"
note "REPO :  $REPO"
note "==============="
note "$(curl -Is https://$REPO)"
note "==============="

is "$(nmap -p 80 $REPO | grep -oP 'open')" 'open' 'port 80 is open' 
is "$(curl -Is http://$REPO | grep -oP 'Location: https')" 'Location: https' 'Header should point to https location' 
is "$(curl -Is http://$REPO | grep -oP '301 Moved')" '301 Moved' 'Header should indicate redirect' 
is "$(curl -L -Is http://$REPO | grep -oP 'HTTP/2 200')" 'HTTP/2 200' 'HTTP/2 200 ok on redirect' 

is "$(nmap -p 443 $REPO | grep -oP 'open')" 'open' 'port 443 is open' 
note "  HEADERS "
is "$(curl -Is https://$REPO | grep -oP 'strict-transport-security')" 'strict-transport-security' 'Strict-Transport-Security' 
is "$(curl -Is https://$REPO | grep -oP 'content-security-policy')" 'content-security-policy' 'content-security-policy' 
is "$(curl -Is https://$REPO | grep -oP 'x-frame-options')" 'x-frame-options' 'x-frame-options' 
is "$(curl -Is https://$REPO | grep -oP 'x-xss-protection')" 'x-xss-protection' 'x-xss-protection'




note "FIN"

# @nmap $(DOMAIN)
# w3m -dump $(DOMAIN)
# @nmap $(DOMAIN)
# w3m -dump_head $(DOMAIN)


