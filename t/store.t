#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $TOKEN"

contentType='content-type: application/xml'
max='1'

importMods=
storePath="xmldb:exist:///db/apps/${DOMAIN}"
fixturesPath="/home/${USER}/projects/${OWNER}/openresty-existdb/t/fixtures"
file='simple.xml'

postData=$(
cat <<EOF
<query xmlns="http://exist.sourceforge.net/NS/exist"
start="1"
wrap="no"
max="${max}">
<text><![CDATA[
xquery version "3.1";
if( file:is-readable('${fixturesPath}/${file}') ) then (
util:compile-query(file:read('${fixturesPath}/${file}'),'${moduleLoadPath}' )
) else (
)
]]></text>
</query>
EOF
)

page="$(
curl -s -i --http1.1 \
 -H "$auth" \
 -H "$contentType" \
 -d "$postData" \
 https://gmack.nz/exist
)"

plan tests 3

note "Compile On The Fly"
note "==============="
note "${page}"
note "==============="
note "the returned content-type attribute value will be application/xml, and "
note "for binary resources application/octet-stream"
is "$(echo $page | grep -oP '200 OK')" '200 OK' 'status indicate 200 OK ' 
is "$(echo $page | grep -oP 'Content-Type: application/xml')" 'Content-Type: application/xml' \
 'Content-Type should be  application/xml' 
ok "$(echo $page | tail -n -1 | grep -q 'pass')" "should  grep pass"



