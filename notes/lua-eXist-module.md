<!--

-->

A module for talking to eXist app via 
[ eXists REST API ](http://exist-db.org/exist/apps/doc/devguide_rest.xml)

- support content negotiation via request headers
 - Method        GET PUT DELETE POST
 - Content-Type  What we are sending
 - Accept        What we want back

Authenticate by Bearer Tokens ove HTTPS

All calls verified by simple curl tests 

curl \
 -X GET \
 -H 'Accept: application/xml' \
 -H "Authorization: Bearer $(<../.site-access-token)" \
 https://gmack.nz/exist

query PATHS

app vs data prefixed paths
/exist/app  resolves to /db/apps/{domain}/{accept}/{id}
/exist/data/posts resolves to /db/data/{domain}/posts/{id}

curl \
 -X GET \
 -H 'Accept: text/css' \
 -H "Authorization: Bearer $(<../.site-access-token)" \
 https://gmack.nz/exist/app/resources/styles/main.css

 resolves /db/apps/{domain}/resources/styles/main.css


curl \
 -X PUT \
 -H "Content-Type: text/css" \
 -H "Authorization: Bearer $(<../.site-access-token)" \
 -d 
 https://gmack.nz/exist/app/resources/styles/main.css

 resolves /db/apps/{domain}/resources/styles/main.css


Multipart Form

curl -X POST \
 -F 'image=@/path/to/image.jpg' \
 https://gmack.nz/exist/app

 resolves /db/apps/{domain}

curl -X POST \
 -F 'file=@/path/to/data.xml \
 https://gmack.nz/exist/data

 resolves /db/data/{domain}

  
 resolves /db/apps/{domain}/resources/styles/main.css

curl \
 -X GET \
 -H 'Accept: application/xml' \
 -H "Authorization: Bearer $(<../.site-access-token)" \
 https://gmack.nz/exist/data/{id}

/db/apps/{domain}/


#  a GET request : data sent in the query part of the URL

curl \
 -GsS \
 -H 'Accept: application/xml' \
 -H "Authorization: Bearer $(<../.site-access-token)" \
 -d "_query="/"
 https://gmack.nz/exist/app/
 





