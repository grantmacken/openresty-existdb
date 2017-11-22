%title:  OpenResty eXist Presentation
%author: Grant Mackenzie

-> mdp basics <-
================

-> A command-line based markdown presentation tool. <-

_Basic controls:_

next slide      *Enter*, *Space*, *Page Down*, *j*, *l*,
                *Down Arrow*, *Right Arrow*

previous slide  *Backspace*, *Page Up*, *h*, *k*,
                *Up Arrow*, *Left Arrow*

quit            *q*
reload          *r*
slide N         *1..9*
first slide     *Home*, *g*
last slide      *End*, *G*

-------------------------------------------------

-> #  A Walk Through Presentation <-

## Recorded Work Through Examples

These are recored using [asciinema](https://asciinema.org)
The hyperlink should appear on the bottom left which you should be able to open in your browser.

```
 ctrl  mouse click
```

-------------------------------------------------

-> # Obtain The Repo <-

 [openresty-existdb ](https://github.com/grantmacken/openresty-existdb)

 - set your git [username](https://help.github.com/articles/setting-your-username-in-git/)
 - set up you projects dir 
 - clone this project

```
mkdir -p ~/projects/$(git config user.name)
cd ~/projects/$(git config user.name)
git clone git@github.com:grantmacken/openresty-existdb.git
```

-------------------------------------------------

## Installing eXist and OpenResty

 -  local development server
 -  remote production server

-------------------------------------------------

-> # Remote Production Server <-

Where we are heading for our remote production server:

 * Our eXist server is proxied behind OpenResty (nginx)
 * OpenResty is the public facing server
 * ufw fire-walls remote server and leaves 3 ports open to the world
    - 1) http:  port *80*
    - 2) https: port *443*
    - 3) ssh:   port *22*
 - Any WWW traffic on port *80* will be _redirected_ to the secure port *433*
 - eXist (jetty) which serves on port *8080* will be _closed_ to the world

 ## Authentication Gateway ##

 Any WWW *authentication* will be done using JWT Bearer tokens over HTTPS. All 
access to eXist is controlled via OpenResty. OpenResty will handle the 
Authorization. Only after Authorized by OpenResty can requests be made to 
eXist in order to access an eXist protected location or query the eXist server.

-------------------------------------------------

