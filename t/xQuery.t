#!/usr/bin/env bash
source t/setup
use Test::More

auth="Authorization: Bearer $TOKEN"

import=
query='util:uuid()'
contentType='content-type: application/xml'
max='1'

# Fixtures.t
postData=$(
cat <<EOF
<query xmlns="http://exist.sourceforge.net/NS/exist"
  start="1"
  wrap="no"
  max="${max}">
<text><![CDATA[
xquery version "3.1";
${import}
${query}
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

note "query "
note "==============="
note "${page}"
note "==============="
note "the returned content-type attribute value will be application/xml, and "
note "for binary resources application/octet-stream"
is "$(echo $page | grep -oP '200 OK')" '200 OK' 'status indicate 200 OK ' 
is "$(echo $page | grep -oP 'Content-Type: application/xml')" 'Content-Type: application/xml' \
 'Content-Type should be  application/xml' 
ok "$([[ -n $(echo $page | tail -n -1) ]])" "$(echo $page | tail -n -1) should be a string"
#is "$(echo $page  | grep -op 'location:')" 'location:' 'should have location in header' 
# is "$(echo $page | grep -op 'x-frame-options')" 'x-frame-options' 'x frame options' 
# isnt "$(echo $page  | grep -oP 'cookie')" 'cookie' 'No cookies sent in Header'

