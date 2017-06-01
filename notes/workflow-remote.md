<!--

-->

- ssh into remote server

open tmux session

```
tmux a -t 0
```
should be in openrest-exisrdb dir

```
git pull
make ngInc
make orModules
make ngDev
make orLoggedErrorFollow
```

on local machine

```
sudo make hostsRemote
make xQdeploy list
make xQdeploy install
make xQdeploy list
make xQregister
```

to send a post

http-prompt
cd micropub
auth-type=jwt
--form
h='entry'
content='post using http prompt'

https://github.com/teracyhq/httpie-jwt-auth

