# openresty-existdb

 A TLS setup for openresty/nginx as reverse proxy for eXistdb

This repo is based on a previous one grantmacken/nginx-exist

I wanted to 
 - enable HTTPS by default
 - explore openresty/lua middleware capability

-------------------------------------------------

# How to use

The repo was designed to be used on a production VPS 
or local development environment.

It assumes you 
1. setup your VPS server with IP address, DNS zones and registered domain(s) etc
2. setup git with configured global [user.name]( https://help.github.com/articles/setting-your-username-in-git/)
 and user.email
     `git config --global user.name` 
     `git config --global user.email`
3. have your own github account and obtained github access token that can be used on the commandline

------------------------------------------------------
