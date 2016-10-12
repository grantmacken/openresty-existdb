--[[

# AUTHORIZATION
 - [authorization-endpoint]( https://indieweb.org/authorization-endpoint )
   identify user OR obtain athorization code 
 use an existing authorization service such as indieauth.com
 
# VERIFICATION
  make a request to the token endpoint to verify that an incoming access token is valid
 server - `verifyAccessToken`

  returns
  Content-Type: application/x-www-form-urlencoded

  inspect these values and determine whether to proceed with the request
  `


 1. client creates post and send to micropub endpoint 
 2. 




 curl -H "authorization: Bearer $(<../.me-access-token)" https://gmack.nz/token

 https://github.com/pintsized/lua-resty-http
 https://github.com/openresty/lua-nginx-module#tcpsocksslhandshake
 https://github.com/openresty/lua-nginx-module#ssl_certificate_by_lua_block
 https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#readme
 https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ocsp.md#readme
 http://lua-users.org/lists/lua-l/2016-01/msg00129.html
 https://github.com/aptise/peter_sslers
 https://indieweb.org/token-endpoint

--]]
module("test", package.seeall)

--ngx.say("test.lua")
-- checkAccessTokenIsValid
-- make request to token issue endpoint
--  GET https://tokens.indieauth.com/token
--  Authorization: Bearer xxxxxxxx
--  returns info about token
--  Check return values 
--  get args 
--  proxy pass

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

function get(token)
  local ssl = require "ngx.ssl"
  local url = require "net.url"
  local jwt = require "resty.jwt"
  local authBearer = ngx.var.http_authorization
  local authToken  = authBearer:split(' ')[2]
  local header     = authToken:split('.')[1]
  local payload    = authToken:split('.')[2]
  local signature  = authToken:split('.')[3]
  local jwtObj = jwt:load_jwt(authToken)
  if not jwtObj.valid then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say("invalid jwt")
    ngx.exit(ngx.HTTP_OK)
  end

  local me = jwtObj.payload.me
  if me == nil then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say("missing me")
    ngx.exit(ngx.HTTP_OK)
  end
  local jwtKeyDict = ngx.shared.tokens
  local key = jwtKeyDict:get(signature)
  local flush = false
  if key == nil then
  ngx.say("key not found in cache" )
    -- key not found in cache, let's check if it's in redis
    -- new key found, if the new key is valid, older ones should be deleted
    --key = redkey(kid)
    -- 
    flush = true
  end
  -- ngx.say(authToken)
  -- ngx.say("alg is: ", jwtObj.header.alg)
  ngx.say("me: ", jwtObj.payload.me)
  -- ngx.say("client_id: ", jwtObj.payload.client_id)
  -- ngx.say("scope: ", jwtObj.payload.scope)
  -- ngx.say("issued_at: ", jwtObj.payload.issued_at)
  -- ngx.say("issues_by: ", jwtObj.payload.issued_by)
  -- ngx.say("nonce: ", jwtObj.payload.nonce)
  ngx.say("signature: ", jwtObj.signature)

  local commonName = ssl.server_name()
  if commonName == nil then
    commonName = "unknown"
  end


  if commonName == url.parse(jwtObj.payload.me).host  then
    ngx.say("OK! ")
  end


end


function getx( token )
  local tokenEndpoint =  'https://tokens.indieauth.com'
  local host = 'tokens.indieauth.com'
  local port = 443
  local http = require "resty.http"
  local httpc = http.new()
  httpc:set_timeout(60000) -- one min timeout
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end

   --ngx.say("successfully connected to ", host)

  -- 4 sslhandshake opts
  local reusedSession = nil -- defaults to nil
  local serverName = host    -- for SNI name resolution
  local sslVerify = false     -- boolean if true make sure the directives set
  -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth 
  local sendStatusReq = '' -- boolean OCSP status request

  local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
  if not shake then
    ngx.say("failed to do SSL handshake: ", err)
    return
  end

   -- ngx.say("ssl handshake: ", type(shake))

   httpc:set_timeout(2000)
   httpc:proxy_response( httpc:request({
         version = 1.1,
         method = "GET",
         path = "/token",
         headers = {
           ["Authorization"] =  ngx.var.http_authorization
         },
         ssl_verify = false
     }))
   httpc:set_keepalive()

end

function get1 (domain)
  local http = require "resty.http"
  local httpc = http.new()
  local host = domain
  local port = 443
  --- 4 sslhandshake opts
  local reusedSession = nil -- defaults to nil
  local serverName = host    -- for SNI name resolution
  local sslVerify = false     -- boolean if true make sure the directives set
  -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth 
  local sendStatusReq = '' -- boolean OCSP status request

  -- set timeout before connecting 
  httpc:set_timeout(60000) -- one min timeout
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end

  -- ngx.say("successfully connected to ", host)

  local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
  if not shake then
    ngx.say("failed to do SSL handshake: ", err)
    return
  end

  -- ngx.say("ssl handshake: ", type(shake))


   httpc:set_timeout(2000)
   httpc:proxy_response( httpc:request({
    version = 1.1,
    method = "GET",
    path = "/",
    headers = { },
    ssl_verify = false
  }))
   httpc:set_keepalive()

  -- local ok, err = httpc:close()
  -- ngx.say("close: ", ok, " ", err)

end

function get2 (domain)
  local http = require "resty.http"
  local httpc = http.new()
  local host = domain
  local port = 443
  --- 4 sslhanshake opts
  local reusedSession = nil -- defaults to nil
  local serverName = host    -- for SNI name resolution
  local sslVerify = false     -- boolean if true make sure the directives set
  -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth 
  local sendStatusReq = '' -- boolean OCSP status request

  -- set timeout before connecting 
  httpc:set_timeout(60000) -- one min timeout
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end

  ngx.say("successfully connected to ", host)

  local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
  if not shake then
    ngx.say("failed to do SSL handshake: ", err)
    return
  end

  ngx.say("ssl handshake: ", type(shake))

  local res, err = httpc:request{
    version = 1.1,
    method = "GET",
    path = "/",
    headers = { },
    ssl_verify = false
  }

  if not res then
    ngx.say("failed to request: ", err)
    return
  end

  ngx.say("status: ", res.status)
  ngx.say("reason: ", res.reason)
  ngx.say("has body: ", res.has_body)

  if res.has_body then
    body, err = res:read_body()
    if not body then
      ngx.say("failed to read body: ", err)
      return
    end

   -- ngx.say(body)

  end



  local ok, err = httpc:close()
  ngx.say("close: ", ok, " ", err)

end

function say (var)
  local sock = ngx.socket.tcp()
  sock:settimeout("60s")
  local ok, err = sock:connect( var, 443)
  if not ok then
    ngx.say("failed to connect to google: ", err)
    return
  end
  ngx.say("successfully connected to google!")


  local sess, err = sock:sslhandshake()
  if not sess then
    ngx.say("failed to do SSL handshake: ", err)
    return
  end

  ngx.say("ssl handshake: ", type(sess))

  local ok, err = sock:close()
  ngx.say("close: ", ok, " ", err)

end
