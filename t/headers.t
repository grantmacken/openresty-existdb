#!/usr/bin/env bash
source t/setup
use Test::More

page=$(curl -s -D - https://gmack.nz | head -n 11)

plan tests 2

note "Page Headers Test Plan"
note "==============="
note "${page}"
note "==============="
note " MORE SECURE HEADER TESTS "
is "$(echo $page | grep -oP 'strict-transport-security')" 'strict-transport-security' 'Strict Transport Security' 
# is "$(echo $page  | grep -oP 'content-security-policy')" 'content-security-policy' 'content security policy' 
# is "$(echo $page | grep -oP 'x-frame-options')" 'x-frame-options' 'x frame options' 
isnt "$(echo $page  | grep -oP 'cookie')" 'cookie' 'No cookies sent in Header'

