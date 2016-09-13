-- test.lua
-- https://github.com/pintsized/lua-resty-http
-- https://github.com/openresty/lua-nginx-module#tcpsocksslhandshake
-- https://github.com/openresty/lua-nginx-module#ssl_certificate_by_lua_block
-- https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#readme
-- https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ocsp.md#readme
-- http://lua-users.org/lists/lua-l/2016-01/msg00129.html
-- https://github.com/aptise/peter_sslers
-- https://indieweb.org/token-endpoint

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

function getx ( token )
  local authorization = ngx.var.http_authorization
  ngx.say(authorization)

end

function get ( token )
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
