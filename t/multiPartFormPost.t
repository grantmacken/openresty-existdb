#!/usr/bin/env bash
source t/setup
use Test::More

file='file=@../gmack.nz/resources/images/opt/gmack.png'
auth="Authorization: Bearer $TOKEN"


page=$( curl -i -X POST --http1.1 -H "$auth" -F $file https://gmack.nz/exist/app )

plan tests 1

note "Multi Part Form Upload"
note "==============="
note "${page}"
note "==============="
is "$(echo $page | grep -oP '200 OK')" '200 OK' 'Status indicate 200 OK ' 
#is "$(echo $page  | grep -oP 'Location:')" 'Location:' 'Should have Location in Header' 
# is "$(echo $page | grep -oP 'x-frame-options')" 'x-frame-options' 'x frame options' 
# isnt "$(echo $page  | grep -oP 'cookie')" 'cookie' 'No cookies sent in Header'

