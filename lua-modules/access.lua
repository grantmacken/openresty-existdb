local _M = {}

--[[

delegation of endpoints for authentication


#
 - [authorization-endpoint]( https://indieweb.org/authorization-endpoint )
   identify user OR obtain athorization code 
 use an existing authorization service such as indieauth.com
 
# VERIFICATION
 [token-endpoint] (https://indieweb.org/token-endpoint)
  grant an access token as well as verify an access token

 is token valid?

  make a request to the token endpoint to verify that an incoming access token is valid
 server - `verifyAccessToken`
 https://tokens.indieauth.com/

  returns
  Content-Type: application/x-www-form-urlencoded

  inspect these values and determine whether to proceed with the request
  `
 1. client creates post and send to micropub endpoint 
 2. sent token will be in the Authorization header or in the post args

 - extractToken
 - verifyToken


lua modules used

@see https://github.com/pintsized/lua-resty-http
@see http://doc.lubyk.org/xml.html

 https://github.com/openresty/lua-nginx-module#tcpsocksslhandshake
 https://github.com/openresty/lua-nginx-module#ssl_certificate_by_lua_block
 https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#readme
 https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ocsp.md#readme
 http://lua-users.org/lists/lua-l/2016-01/msg00129.html
 https://github.com/aptise/peter_sslers

@see  https://indieweb.org/token-endpoint
@see  https://www.w3.org/TR/micropub/
 
 - MUST support both header and form parameter methods of authentication
 - MUST support creating posts with the [h-entry] vocabulary

TEST: curl

1. token in the HTTP Authorization header

 curl -H "authorization: Bearer $(<../.me-access-token)" https://gmack.nz/micropub

2. token in the post body for x-www-form-urlencoded requests

curl -L  https://gmack.nz/micropub -d "access_token=$(<../.me-access-token)"

3. POST   x-www-form-urlencoded 

 curl -H "authorization: Bearer $(<../.me-access-token)" https://gmack.nz/micropub  -d 'h=entry' -d 'content=hello moon'

 4. POST application/json

 curl -H "Content-Type: application/json"  -H "authorization: Bearer $(<../.me-access-token)" https://gmack.nz/micropub -d '{"type": ["h-entry"],"properties":{"content": ["hello world"]}}'


 id unique to the db
   [a-z]{1}  shortKindOfPost n = note
   O
   [\w]{3}   short date base60 encoded 
   [\w]{1}   the base60 encoded incremented number of entries for the day
   total of 5 chars 
  the short URL http://{domain}/{uid)  - no extension
  expanded  URL http://{domain}/{YEAR}/{MONTH}/{DAY}/{KIND}/{CHAR}
  where kind = kind of post e.g. note
  where char = the incremented entry number for the day
  5 chars limited to less than 60 entries for the day
  6 chars  limited to less than 360 entries for the day

  URL http://{domain}/{YEAR}/{MONTH}/{DAY}/notes
  list notes for day

  URL http://{domain}/{YEAR}/{MONTH}/{DAY}
  list any archived posts for day

  URL http://{domain}/{YEAR}/{MONTH}
  list archived posts for month 

  URL http://{domain}/{YEAR}/{MONTH}/notes
  list notes for month
  
  etc

--]]

function string:split(delimiter)
  local result = { }
  local from = 1
  local delim_from, delim_to = string.find( self, delimiter, from )
  if delim_from == nil then return {self} end
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from )
  end
  table.insert( result, string.sub( self, from ) )
  return result
end

--[[
3.8 Error Response
https://www.w3.org/TR/micropub/#error-response
--]]

local function requestError( status, msg ,description)
  ngx.status = status
  ngx.header.content_type = 'application/json'
  local json = cjson.encode({
      error  = msg,
      error_description = description
    })
  ngx.print(json)
  ngx.exit(status)
end

function extractToken()
  --TODO! token in post args
  --access_token - the OAuth Bearer token authenticating the request
  --(the access token may be sent in an HTTP Authorization header or
  --this form parameter)
  local token  = ngx.var.http_authorization
  if token  ~=  nil then
     token  = token:split(' ')[2]
     return token
   end

  ngx.req.read_body()
  local token  = ngx.req.get_post_args()['access_token']
  if token  ~=  nil then
    return token 
  end

 return  requestError(ngx.HTTP_UNAUTHORIZED,'error', 'unauthorized') 
end

function _M.verifyToken()
  local ssl = require "ngx.ssl"
  local jwt = require "resty.jwt"
  local jwtObj = jwt:load_jwt(extractToken())

  if not jwtObj.valid then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'not a jwt token') 
  end

  local me = jwtObj.payload.me
  if me == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing me') 
  end

  local clientID = jwtObj.payload.client_id
  if clientID == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing client id') 
  end

  local scope = jwtObj.payload.scope
  if scope == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing scope') 
  end

  local issuedAt = jwtObj.payload.issued_at
  if  issuedAt == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing issued_at') 
  end

  local issuedBy = jwtObj.payload.issued_by
  if  issuedBy == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing issued by') 
  end

  -- local json = cjson.encode(jwtObj.payload)
  -- ngx.say(json)

-- am I the one who authorized the use of this token
-- TODO! establish my sni name

  local serverName = ssl.server_name()
  if serverName == nil then
   return  requestError(ngx.HTTP_FORBIDDEN,'insufficient_scope', 'can not establish server name') 
  end

  -- if serverName ~= ngx.var.site then
  --  return  requestError(ngx.HTTP_FORBIDDEN,'insufficient_scope', 'you are not me') 
  -- end

-- I have the appropiate post scope
  if scope ~= 'post'  then
   return  requestError(ngx.HTTP_FORBIDDEN,'insufficient_scope', ' do not have the appropiate post scope') 
  end

-- I have the appropiate post scope
-- TODO! scope is a list
--  ngx.say(clientID)

-- I accept posts only from the following clients
-- TODO!
--
-- I accept tokens no older than 
-- -- TODO!

 return 'token verifed'

-- return ngx.encode_args(jwtObj.payload)
-- return cjson.encode(jwtObj.payload)

  -- ngx.status =  ngx.status = ngx.HTTP_OK
  -- ngx.header.content_type = 'application/json'
  -- local json = cjson.encode(jwtObj.payload)
  -- ngx.say(json)
  -- ngx.exit(ngx.HTTP_OK)
end

return _M
