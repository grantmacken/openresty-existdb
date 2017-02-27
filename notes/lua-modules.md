<!--

-->

```
make opmGet
make orModules
```

 opmGet : get a list of opm Modules
 adjust list in `mk-includes/or-modules.mk`

 orModules: copy any files over into OpenResty site/lualib/$(GIT_USER)  dir

Modules placed under $(GIT_USER) to follow opmi the git-user-name/module-name install pattern.

