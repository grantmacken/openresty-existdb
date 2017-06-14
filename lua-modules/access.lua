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
  --ngx.log(ngx.INFO, "Extract Token")
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
      return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', 'read body but no token') 
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
  --ngx.log(ngx.INFO, "Verify Token")
  local msg = ''
  local tokens = ngx.shared.dTokens
  local token = extractToken()
  -- ngx.say( 'token: ' .. token )
  local jwt = require "resty.jwt"
  local jwtObj = jwt:load_jwt(token)

  if isTokenValid( jwtObj ) then
    --ngx.log(ngx.INFO, " Token is valid jwt object")
    -- -- if a token has been verified the in will be stores in shared dic
     local thisDomain =  extractDomain( jwtObj.payload.me )
     --ngx.log(ngx.INFO, "who am I := " .. thisDomain )
     local clientDomain =  extractDomain( jwtObj.payload.client_id )
     --ngx.log(ngx.INFO, "Client Domain := " .. clientDomain )
     local domainHash = ngx.encode_base64( thisDomain .. clientDomain , true)
    local value, flags = tokens:get( domainHash )
    if not value then
      --ngx.log(ngx.INFO, 'Token has not been verified at token endpoint')
      if verifyAtTokenEndpoint( 'token' ) then
        --ngx.log(ngx.INFO, 'Token verified at token endpoint')
        tokens:set(domainHash, true)
        return true
      else
        msg = "failed to verfify token at token endpoint: " 
        return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
      end
    else
      --ngx.log(ngx.INFO, 'Token has already been verified at token endpoint ')
      --TODO! for testing only
     --  tokens:set(domainHash, nil)
      return true
    end
  else 
    --ngx.log(ngx.Warn, 'Token not Veriified')
    -- oh NO! should not end up here
    msg = "failed to validate token "
    return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
  end
end

function isTokenValid( jwtObj )
  --ngx.log(ngx.INFO, "Check The Tokens Validity")
  if not jwtObj.valid then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'not a jwt token') 
  end
  --ngx.log(ngx.INFO, 'Yep!: looks like a JWT token ')
  local me = jwtObj.payload.me
  if me == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing me') 
  end

  local clientID = jwtObj.payload.client_id
  if clientID == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing client id') 
  end
  --ngx.log(ngx.INFO, 'Yep!: has a client id  [ ' .. clientID  .. ' ] ')

  local scope = jwtObj.payload.scope
  if scope == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing scope') 
  end
  --ngx.log(ngx.INFO, 'Yep!: has a scope [ ' .. scope  .. ' ] ')

  local issuedAt = jwtObj.payload.issued_at
  if  issuedAt == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing issued_at') 
  end
  --ngx.log(ngx.INFO, 'Yep!: has a issued at date [ ' .. issuedAt  .. ' ] ')

  local issuedBy = jwtObj.payload.issued_by
  if  issuedBy == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing issued by') 
  end
  --ngx.log(ngx.INFO, 'Yep!: has a issued by domain [ ' .. issuedBy  .. ' ] ')

  local thisDomain =  extractDomain( me )
  if ngx.var.domain  ~=  thisDomain  then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'you are not me') 
  end
  --ngx.log(ngx.INFO, 'Yep!: I am the one who authorized the use of this token')

  --ngx.log(ngx.INFO, 'Check: I have the appropiate create update scope')
  if scope ~= 'create update'  then
    return  requestError(
      ngx.HTTP_UNAUTHORIZED,
      'insufficient_scope',
      ' do not have the appropiate "create update" scope')
  end
  --ngx.log(ngx.INFO, 'Yep!: I have the appropiate post scope')

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
    --ngx.log(ngx.INFO, "Verify At Token Endpoint... ")
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

    --ngx.log(ngx.INFO, 'Connected to '  .. host ..  ' on port '  .. port)
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

    --ngx.log(ngx.INFO, "SSL Handshake Completed: "  ..type(shake))
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

   --ngx.log(ngx.INFO, "Request Response Status: " .. response.status)
   --ngx.log(ngx.INFO, "Request Response Reason: " .. response.reason)

   if response.has_body then
     body, err = response:read_body()
     if not body then
       msg = "failed to read post args: " ..  err
       return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
     end
     --ngx.log(ngx.INFO, "verify body recieved: ")
     local args = ngx.decode_args(body, 0)
     if not args then
       msg = "failed to decode post args: " ..  err
       return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg ) 
     end
     --ngx.log(ngx.INFO, "verify body decoded: OK")
     local myDomain = extractDomain( args['me'] )
     -- local clientDomain = extractDomain( args['client_id'] )
     --ngx.log(ngx.INFO, "Am I the one who authorized the use of this token?")
     if ngx.var.domain  ~=  myDomain  then
       return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'you are not me') 
     end
     --ngx.log(ngx.INFO, 'Yep! ' .. ngx.var.domain .. ' same domain as '  .. myDomain   )

     --ngx.log(ngx.INFO, "Do I have the appropiate post scope?")
     if args['scope'] ~= 'post'  then
       return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', ' do not have the appropiate post scope') 
     end
      --ngx.log(ngx.INFO, "Yep! post scope  equals: " ..  args['scope'])
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
