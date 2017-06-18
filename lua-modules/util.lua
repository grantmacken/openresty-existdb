local _M = {}

function _M.read(f)
  local open     = io.open
  local f, e = open(f, "rb")
  if not f then
    return nil, e
  end
  local c = f:read "*a"
  f:close()
  return c
end

function _M.tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end


local function contains(tab, val)
  for index, value in ipairs (tab) do
    if value == val then
      return true
    end
  end
  return false
end


--UTILITY TODO move to utility.lua
-- utility REQUEST functions
--
--[[
-- a simple GET request wrapper for resty-http
-- @see https://github.com/pintsized/lua-resty-http
-- @param URL 
-- @returns  response table , err
--]]--
function _M.fetch( url )
  ngx.log( ngx.INFO, " FETCH a simple GET " )
  ngx.log( ngx.INFO, " - fetch: "  .. url )
  local msg = ''
  local httpc = require('resty.http').new()
  local scheme, host, port, path = unpack(httpc:parse_uri(url))
  ngx.log( ngx.INFO, " - scheme: "  .. scheme )
  httpc:set_timeout(2000) -- 2 sec timeoutlog( ngx.INFO, " - fetch: "  .. url )
  local ok, err = httpc:connect( host, port )
  if not ok then
    msg = "FAILED to connect to " .. host .. " on port "  .. port
    ngx.log( ngx.INFO, msg )
    return {}, msg
  else
    ngx.log( ngx.INFO, " - connected to " .. host .. " on port "  .. port )
  end

  if scheme == 'https' then
    -- 4 sslhandshake opts
    local reusedSession = nil   -- defaults to nil
    local serverName = host     -- for SNI name resolution
    local sslVerify = false     -- boolean if true make sure the directives set
    -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth 
    local sendStatusReq = '' -- boolean OCSP status request
    local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
    if not shake then
      ngx.log(
        ngx.INFO,
        'FAILED SSL handshake with  '  .. serverName ..  ' on port '  .. port )
      return {}, msg
    else
      ngx.log( ngx.INFO, " - SSL Handshake Completed: "  .. type(shake))
    end
  end

  -- local DEFAULT_PARAMS 
  --   method = "GET",
  --   path = "/",
  --   version = 1.1,
  --  also defaults to
  --  headers["User-Agent"] = _M._USER_AGENT
  --  if SSL headers["Host"] = self.host .. ":" .. self.port
  --  else headers["Host"] = self.host
  --  headers["Connection"] = "Keep-Alive"
  --  if body will also add 
  --  headers["Content-Length"] = #body

   httpc:set_timeout(2000)
   local response, err = httpc:request({
        ["path"] = path
     })

   if not response then
     msg = "failed to complete request: ", err
     ngx.log( ngx.INFO, msg )
     return {}, msg
   end
  return response, err
end


function _M.post( url, contentType, body )
  local msg = ''
  local httpc = require('resty.http').new()
  local scheme, host, port, path = unpack(httpc:parse_uri(url))
  httpc:set_timeout(6000) -- 6 sec timeout
  local ok, err = httpc:connect(host, port)
  if not ok then
    msg = "FAILED to connect to " .. host .. " on port "  .. port .. ' - ERR: ' ..  err
    return {}, msg
  else
      ngx.log(
        ngx.INFO,
        " - connected to " .. host .. " on port "  .. port )
  end
  if scheme == 'https' then
    -- 4 sslhandshake opts
    local reusedSession = nil   -- defaults to nil
    local serverName = host     -- for SNI name resolution
    local sslVerify = false     -- boolean if true make sure the directives set
    -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth 
    local sendStatusReq = '' -- boolean OCSP status request
    local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
    if not shake then
      ngx.log(
        ngx.INFO,
        'FAILED SSL handshake with  '  .. serverName ..  ' on port '  .. port )
      return {}, msg
    else
      ngx.log(
        ngx.INFO,
        " - SSL Handshake Completed: "  .. type(shake))
    end
  end
   httpc:set_timeout(6000)
   local response, err = httpc:request({
      ['method'] = "POST",
      ['path'] = path,
      ['headers'] = {
        ["Content-Type"] = contentType,
      },
      ['body'] = body
     })

   if not response then
     msg = "failed to complete request: ", err
     ngx.log( ngx.INFO, msg )
     return {}, msg
   end
   msg = " -  post request complete"
   ngx.log( ngx.INFO, msg )
   msg = response.reason
   ngx.log( ngx.INFO, msg )
   return response, err
 end


--
--UTILITY TODO move to utility.lua

function _M.requestError( status, msg, description )
  ngx.status = status
  ngx.header.content_type = 'application/json'
  local json = cjson.encode({
      error  = msg,
      error_description = description
    })
  ngx.print(json)
  ngx.exit(status)
end

function _M.acceptMethods( methods )
  -- ngx.say( 'the methods this endpoint can handle' )
  local method = ngx.req.get_method()
  if not contains( methods, method )  then
    return _M.requestError(
      ngx.HTTP_METHOD_NOT_IMPLEMENTED,
      method .. ' method not implemented',
      'endpoint does not accept' .. method .. 'methods')
  end
 return method
end

function _M.acceptContentTypes( contentTypes )
  --ngx.say("the content types this endpoint can handle")
  local contentType = ngx.var.http_content_type
  if not contentType then
    local msg = 'should have a content type'
    return _M.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted ',
      msg )
  end
  local from, to, err = ngx.re.find(contentType ,"(multipart/form-data|application/x-www-form-urlencoded|multipart/form-data)")
  if from then
    contentType =  string.sub( contentType, from, to )
  end
  if not contains( contentTypes, contentType )  then
    local msg = 'endpoint does not accept' .. contentType
    return _M.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted ',
      msg )
  end
  return contentType
end

function _M.acceptFormArgs( args , acceptArgs )
  for key, value in pairs( args ) do
    ngx.log(ngx.INFO, key )
    if not contains( acceptArgs, key )  then
      return _M.requestError(
        ngx.HTTP_NOT_ACCEPTABLE,
        'not accepted',
        'endpoint only does not accept ' .. key  )
    end
  end
 return true
end

function _M.extractID( url )
  -- short urls https://gmack.nz/xxxxx
  local sID, err = require("ngx.re").split(url, "([nar]{1}[0-9A-HJ-NP-Z_a-km-z]{4})")[2]
  if err then
    local msg = 'could not extract id from URL'
    return _M.requestError( ngx.HTTP_BAD_REQUEST,'bad request', msg)
  end
  return sID
end
return _M
