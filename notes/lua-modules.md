<!--

-->

```
make opmGet
make orModules
sudo make ngDev
make orLoggedErrorFollow
make orServiceLogFollow
```

 opmGet : get a list of opm Modules
 adjust list in `mk-includes/or-modules.mk`

 orModules: copy any files over into OpenResty site/lualib/$(GIT_USER)  dir

Modules placed under $(GIT_USER) to follow opmi the git-user-name/module-name install pattern.

 - access module file: `lua-modules/access.lua`

Authorizations to protected areas site is done thru Bearer tokens over HTTPS
 as described in [rfc6750](http://www.rfc-editor.org/rfc/rfc6750.txt)

curl -H  "Authorization: Bearer mytoken123"  https://gmack.nz

make orModules && curl -G -H "Authorization: Bearer $(<../.site-access-token)" https://gmack.nz/exist

curl -H "Content-Type: application/xml" -G -H "Authorization: Bearer $(<../.site-access-token)" https://gmack.nz/exist


