#!/usr/bin/env bash
source t/setup
use Test::More

page=$(curl -s -D - https://gmack.nz | head -n 11)

plan tests 4

note "Headers Test Plan"
note "==============="
note "page headers : "
note "==============="
note "${page}"
note "==============="
note " MORE SECURE HEADER TESTS "
is "$(echo $page | grep -oP 'strict-transport-security')" 'strict-transport-security' 'Strict Transport Security' 
is "$(echo $page  | grep -oP 'content-security-policy')" 'content-security-policy' 'content security policy' 
is "$(echo $page | grep -oP 'x-frame-options')" 'x-frame-options' 'x frame options' 
is "$(echo $page  | grep -oP 'cookie')" 'cookie' 'Yep! no cookies sent in Header'

