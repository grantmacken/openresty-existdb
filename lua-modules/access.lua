local _M = {}

--[[

delegation of endpoints for authentication

#
 - [authorization-endpoint]( https://indieweb.org/authorization-endpoint )
   identify user OR obtain athorization code 
 use an existing authorization service such as indieauth.com
 
# VERIFICATION
 [token-endpoint] (https://indieweb.org/token-endpoint)

  1. grant an access token 
  2. verify an access token

 Micropub endpoint interested in -- 2

  Requests with tokens
  so we need to verify token validity

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

function extractDomain( url )
  local sDomain, err = require("ngx.re").split(url, "([/]{1,2})")[3]
  if err then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  return sDomain
end


function extractToken()
  --TODO! token in post args
  --access_token - the OAuth Bearer token authenticating the request
  --(the access token may be sent in an HTTP Authorization header or
  --this form parameter)
  if ngx.var.http_authorization == nil then
    ngx.req.read_body()
    local token  = ngx.req.get_post_args()['access_token']
    if token  ~=  nil then
      return token 
    else
      return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', 'no token') 
    end
  else
    local token, err = require("ngx.re").split(ngx.var.http_authorization,' ')[2]
    if err then 
      return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', 'no token') 
    end
    return token
  end
end


function _M.verifyToken()
  -- ngx.say("Verify Token")
  local msg = ''
  local tokens = ngx.shared.dTokens
  local token = extractToken()
  local jwt = require "resty.jwt"
  local jwtObj = jwt:load_jwt(token)

  if isTokenValid( jwtObj ) then
    -- ngx.say( ' -  token is valid ' )
    -- if a token has been verified the in will be stores in shared dic
    local thisDomain =  extractDomain( jwtObj.payload.me )
    local clientDomain =  extractDomain( jwtObj.payload.client_id )
    local domainHash = ngx.encode_base64( thisDomain .. clientDomain , true)
    local value, flags = tokens:get( domainHash )
    if not value then
      -- ngx.say( ' token has not been verified ' )
      if verifyAtTokenEndpoint( 'token' ) then
        -- ngx.say( ' token verified at token endpoint ' )
        tokens:set(domainHash, true)
        return true
      else
        msg = "failed to verfify token at token endpoint: " 
        return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
      end
    else
      return true
    end
  else
    -- should not endup here
    msg = "failed to validate token "
    return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
  end
end

function isTokenValid( jwtObj )
  if not jwtObj.valid then
   return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'not a jwt token') 
  end

  local me = jwtObj.payload.me
  if me == nil then
   return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing me') 
  end

  local clientID = jwtObj.payload.client_id
  if clientID == nil then
   return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing client id') 
  end

  local scope = jwtObj.payload.scope
  if scope == nil then
   return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing scope') 
  end

  local issuedAt = jwtObj.payload.issued_at
  if  issuedAt == nil then
   return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing issued_at') 
  end

  local issuedBy = jwtObj.payload.issued_by
  if  issuedBy == nil then
   return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing issued by') 
  end

-- am I the one who authorized the use of this token
  local thisDomain =  extractDomain( me )
  if ngx.var.domain  ~=  thisDomain  then
   return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'you are not me') 
 end

-- I have the appropiate post scope
  if scope ~= 'post'  then
   return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', ' do not have the appropiate post scope') 
 end

-- I have the appropiate post scope
-- TODO! scope is a list
--  ngx.say(clientID)

-- I accept posts only from the following clients
-- TODO!
--
-- I accept tokens no older than 
-- -- TODO!

 return true
 
 end

 function verifyAtTokenEndpoint( )
   local msg = ''
   local tokenEndpoint =  'https://tokens.indieauth.com'
   local host = 'tokens.indieauth.com'
   local port = 443
   local http = require "resty.http"
   local httpc = http.new()
   httpc:set_timeout(60000) -- one min timeout
   local ok, err = httpc:connect(host, port)
   if not ok then
     msg = "failed to connect to ",host ," ",  err
     return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
   end
   -- 4 sslhandshake opts
   local reusedSession = nil -- defaults to nil
   local serverName = host    -- for SNI name resolution
   local sslVerify = false  -- boolean if true make sure the directives set
   -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth 
   local sendStatusReq = '' -- boolean OCSP status request

   local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
   if not shake then
     msg = "failed to do SSL handshake: ", err
     return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
   end

   -- ngx.say("ssl handshake: ", type(shake))
   --ngx.var.http_authorization

   httpc:set_timeout(2000)
   local response, err = httpc:request({
       version = 1.1,
       method = "GET",
       path = "/token",
       headers = {
         ["Authorization"] =  ngx.var.http_authorization
       },
       ssl_verify = sslVerify
     })

   if not response then
     msg = "failed to complete request: ", err
     return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
   end

   ngx.say("status: ", response.status)
   -- ngx.say("reason: ", response.reason)
   -- ngx.say("has body: ", response.has_body)

   if response.has_body then
     body, err = response:read_body()
     if not body then
       msg = "failed to read post args: " ..  err
       return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
     end

     local args = ngx.decode_args(body, 0)  
     if not args then
       msg = "failed to decode post args: " ..  err
       return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
     end

     local myDomain = extractDomain( args['me'] )
     -- local clientDomain = extractDomain( args['client_id'] )
     -- am I the one who authorized the use of this token
     if ngx.var.domain  ~=  myDomain  then
       return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'you are not me') 
     end
     -- I have the appropiate post scope
     if args['scope'] ~= 'post'  then
       return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', ' do not have the appropiate post scope') 
     end
     return true
   else
     return false
   end
   return false
 end

  --   ngx.say( myDomain )
  --   ngx.say(args['issued_by'])
  --   ngx.say(args['client_id'])
  --   ngx.say(args['issued_at'])
  --   ngx.say(args['scope'])
  --   ngx.say(args['nonce'])
  --   ngx.say(myURL)
    -- ngx.say(ngx.var.uri)
    -- ngx.say(ngx.var.server_name)
    -- ngx.say(ngx.var.server_addr)
    -- ngx.say(ngx.var.domain)
    -- ngx.say(ngx.var.realpath_root)
    -- ngx.say(ngx.var.host)
    -- ngx.say(ngx.var.https)
    -- ngx.say(ngx.var.request)
    -- ngx.say(ngx.var.request_uri)
    -- ngx.say(ngx.var.scheme)
return _M
