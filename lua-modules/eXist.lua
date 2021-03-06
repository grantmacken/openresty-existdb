local _M = {}

local util    = require('grantmacken.util')
local config  = require('grantmacken.config')

local reqargsOptions = {
  timeout          = 1000,
  chunk_size       = 4096,
  max_get_args     = 100,
  mas_post_args    = 100,
  max_line_size    = 512,
  max_file_uploads = 10
}

local extensions = {
png = 'image/png',
jpg = 'image/jpeg',
jpeg = 'image/jpeg',
gif = 'image/gif'
}

local assetRoute = {
image  =   'resources/images',
scripts  = 'resources/styles',
styles  =  'resources/styles',
icons  =   'resources/icons'
}

-- ++++++++++++++++++++++++++++++++++++++++++

function read(f)
  local open     = io.open
  local f, e = open(f, "rb")
  if not f then
    return nil, e
  end
  local c = f:read "*a"
  f:close()
  return c
end
--
--UTILITY TODO move to utility.lua
local function contains(tab, val)
  for index, value in ipairs (tab) do
    if value == val then
      return true
    end
  end
  return false
end


-- function acceptFormFields(fields , field)
--   --  the multpart form fields  this endpoint can handle
--   if not contains( fields, field )  then
--     return requestError(
--       ngx.HTTP_NOT_ACCEPTABLE,
--       'not accepted',
--       'endpoint only doesnt accept' .. field )
--   end
--  return method  
-- end

function getMimeType( filename )
  -- get file extension Only handle 
  local ext, err = ngx.re.match(filename, "[^.]+$")
  if ext then
   return ext[0], extensions[ext[0]]
  else
    if err then
      ngx.log(ngx.ERR, "error: ", err)
      return
    end
    ngx.say("match not found")
  end
end

-- ++++++++++++++++++++++++++++++++++++++++++
--  MAIN endpoint for exist requests
--  https://<domain>//eXist/

function _M.processRequest()
  ngx.log(ngx.INFO, "Process Request" )
  local method =  util.acceptMethods({"POST","GET" , "DELETE"})
  ngx.log(ngx.INFO, "Accepted Method [ " .. method  .. ' ]')
  if ( method == "POST" ) then
    processPost()
  elseif (  method == "PUT" ) then
    -- processPut method )
  else 
    processGetDelete()
  end
end

function processGetDelete( method )
  ngx.log(ngx.INFO, "Process GET DELETE requests to eXist endpoint")
  ngx.log(ngx.INFO, ngx.var.uri)
  local response = {}
  local msg = ''
  local args = ngx.req.get_uri_args()
  if not args[1] then
    ngx.log(ngx.INFO, "Look for path")
    local sID= require('ngx.re').split(ngx.var.uri, '/')[3]
    local from, to, err = ngx.re.find(
    sID,
    "([rnap]{1})([0-9A-HJ-NP-Z_a-km-z]{3})([0-9A-HJ-NP-Z_a-km-z]{1})", 
    "jo")
    if from then
      -- ngx.say("from: ", from)
      -- ngx.say("to: ", to)
      local matched = string.sub(sID, from, to)
      ngx.log(ngx.INFO, "matched: ", matched )
       _M.proxyGetDelete( 'posts' , matched )
    else
      if err then
        msg =  "error: " .. err
        ngx.log(ngx.WARN, msg)
        util.requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
      end
      msg =  "error: not valid uid"
      ngx.log(ngx.WARN, msg)
     util.requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
    end

    -- if sID ~= '' then
    -- else
    -- msg =  "TODO! : " .. type(sID)
    -- ngx.log(ngx.WARN, msg)
    -- requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
    -- end
  end
    -- TODO!
    -- ngx.log(ngx.INFO, "Look for path")
    -- for key, val in pairs(args) do
    --   if type(val) == "table" then
    --     ngx.say(key, ": ", table.concat(val, ", "))
    --   else
    --     ngx.say(key, ": ", val)
    --   end
    -- end
end

function processPost()
  -- ngx.log(ngx.INFO, "Process the content-types this endpoint can handle")
  -- mainly handle eXist rest endpoint
  local contentType = util.acceptContentTypes({
      'application/xquery',
      'application/xml',
      'application/json',
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    })
--[[
POST  If the remainder of the URI (the part after /exist/rest) i
 references an XQuery program stored in the database, it will be executed.
]]--
  ngx.log(ngx.INFO, "Accepted Content Type [ " .. contentType  .. ' ]')
  --  ngx.say( contentType )
  if contentType  == 'application/x-www-form-urlencoded' then
    --processPostArgs()
  elseif contentType  == 'multipart/form-data' then
    processMultiPartForm()
  elseif contentType  == 'application/json' then
    processJsonBody()
  elseif contentType  == 'application/xml' then
    processXqueryXML()
  elseif contentType  == 'application/xquery' then
    processXqueryFile()
  end
end


function processJsonBody()
  ngx.log(ngx.INFO, "Process JSON Body")
  ngx.req.read_body()
  local data = ngx.req.get_body_data()
  ngx.log(ngx.INFO, type(data))
  ngx.log(ngx.INFO, ngx.var.uri)

  local sPath, n, err =  ngx.re.sub( ngx.var.uri, "/_exist", "")
  -- ngx.log(ngx.INFO, data)
  local restPath =  '/exist/rest/db/apps/' .. ngx.var.domain .. ngx.re.sub( ngx.var.uri, "/_exist", "")

  local http = require "resty.http"
  local httpc = http.new()
  local ok, err = httpc:connect(config.get('host'), config.get('port'))
  if not ok then 
    return requesterror(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  ngx.log(ngx.INFO, 'Connected to '  .. config.get('host') ..  ' on port '  .. config.get('port'))
  httpc:set_timeout(2000)
  httpc:proxy_response( httpc:request({
        version = 1.1,
        method = "POST",
        path = restPath,
        headers = {
          ["Content-Type"] =  ngx.header.content_type,
          ["Authorization"] = config.get('auth')
        },
        body =  data,
        ssl_verify = false
    }))
  httpc:set_keepalive()
end

function processXqueryFile()
  ngx.log(ngx.INFO, "Process xQuery File")
  ngx.req.read_body()
  local data = ngx.req.get_body_data()
  ngx.log(ngx.INFO, type(data))
  ngx.log(ngx.INFO, ngx.var.uri)

  local sPath, n, err =  ngx.re.sub( ngx.var.uri, "/_exist", "")
  -- ngx.log(ngx.INFO, data)
  local restPath =
  '/exist/rest/db/apps/' .. ngx.var.domain .. ngx.re.sub( ngx.var.uri, "/_exist", "")

  local http = require "resty.http"
  local httpc = http.new()
  local ok, err = httpc:connect(config.get('host'), config.get('port'))
  if not ok then 
    return util.requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  ngx.log(ngx.INFO, 'Connected to '  .. config.get('host') ..  ' on port '  .. config.get('port'))
  httpc:set_timeout(2000)
  httpc:proxy_response( httpc:request({
        version = 1.1,
        method = "POST",
        path = restPath,
        headers = {
          ["Content-Type"] =  ngx.header.content_type,
          ["Authorization"] = config.get('auth') 
        },
        body =  data,
        ssl_verify = false
    }))
  httpc:set_keepalive()
end

function processXqueryXML()
  ngx.log(ngx.INFO, " Process xQuery ")
  ngx.log(ngx.INFO, "----------------")
  ngx.req.read_body()
  local data = ngx.req.get_body_data()
   ngx.log(ngx.INFO, ' - got sent body data' ) 
   ngx.log(ngx.INFO, data)
  local restPath =  '/exist/rest/db/apps/' ..  ngx.var.domain
  local httpc = require("resty.http").new()
  local ok, err = httpc:connect(config.get('host'), config.get('port'))
  if not ok then 
    return util.requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  ngx.log(ngx.INFO, ' connected to '  .. config.get('host') ..  ' on port '  .. config.get('port'))
  httpc:set_timeout(2000)
  httpc:proxy_response( httpc:request({
        version = 1.1,
        method = "POST",
        path = restPath,
        headers = {
          ["Content-Type"] =  ngx.header.content_type,
          ["Authorization"] = config.get('auth')
        },
        body =  data,
        ssl_verify = false
    }))
  httpc:set_keepalive()
end

function processMultiPartForm()
  ngx.log(ngx.INFO, 'process Multi Part Form')
  if ngx.var.http2 ~= 'h2' then
    msg = 'Upload only done with HTTP1.1'
    ngx.log(ngx.INFO, msg)
  else
    ngx.log(ngx.INFO,  'http version 2 ' .. ngx.var.http2)
    msg = 'Upload only done with HTTP1.1'
    ngx.log(ngx.WARN, msg)
    requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
  end
 
  local msg = ''

  -- https://github.com/bungle/lua-resty-reqargs 
  local split = require( "ngx.re" ).split
  local reqargs = require "resty.reqargs"
  local get, post, files = reqargs( reqargsOptions )
   if not get then
    error(post)
  end

  ngx.log(ngx.INFO, 'FILES')
  for key, val in pairs(files) do
    if type(val) == "table" then
      ngx.log(ngx.INFO,'key', ": ", key)
      ngx.log(ngx.INFO, 'value type: ' ..  type(val))
      for k, v in pairs( val ) do
        ngx.log(ngx.INFO,'key', ": ", k)
        ngx.log(ngx.INFO, 'value type: ' ..  v)
      end
    else
      ngx.log(ngx.INFO,'key', ": ", key)
    end
  end

  local properties = {}

  for key, val in pairs(files) do
    if type(val) == "table" then
      local ext, mimeType = getMimeType( val.file )
      local properties = {}
      properties[ 'mimeType' ] =  mimeType
      -- ngx.log(ngx.INFO,'key', ": ", key)
      -- ngx.log(ngx.INFO, 'value type: ' ..  type(val))
      properties['name']      = val.file
      properties['size']      = val.size
      properties['temp']      = val.temp
      properties['uploaded']  = ngx.today()
      properties['signature'] = ngx.md5(part_body)
      properties['mime']      = mimeType
      properties['extension'] = ext

      ngx.log(ngx.INFO,     'name [ ' ..  properties.name      .. ' ]')
      ngx.log(ngx.INFO,     'mime [ ' ..  properties.mime      .. ' ]')
      ngx.log(ngx.INFO,     'temp [ ' ..  properties.temp      .. ' ]')
      ngx.log(ngx.INFO,     'size [ ' ..  properties.size      .. ' ]')
      ngx.log(ngx.INFO, 'uploaded [ ' ..  properties.uploaded  .. ' ]')
      ngx.log(ngx.INFO,'signature [ ' ..  properties.signature .. ' ]')
      ngx.log(ngx.INFO,'extension [ ' ..  properties.extension .. ' ]')

      local whereToType = 'data'
      if  split( ngx.var.uri , '/')[3] == 'app' then
        whereToType = 'apps'
      end

      if whereToType == 'apps' then

        -- get aset route
        local assetType = split( mimeType, '/')[1] 
        ngx.log(ngx.INFO,'assetType [ ' ..  assetType .. ' ]')
        if assetType ~= 'image' then
          assetType = split( mimeType, '/')[2] 
        end

        -- TODO!
        properties['path'] =  '/exist/rest/db/' ..  whereToType  .. 
        '/'  .. ngx.var.domain  .. '/' ..  assetRoute[assetType] .. '/' .. properties.name

        properties['location'] = 'https://' .. ngx.var.domain ..  '/' ..
        assetRoute[assetType] .. '/' .. properties.name

        if  assetType == 'image' then
          ngx.log(ngx.INFO, 'REST :path [ '  ..  properties.path .. ' ]'   )
          ngx.log(ngx.INFO, 'mime: [ '  ..  properties.mime .. ' ]'   )
          ngx.log(ngx.INFO, 'temp: [ '  ..  properties.temp .. ' ]'   )
          ngx.log(ngx.INFO, 'location: [ '  ..  properties.location .. ' ]'   )
          if putAsset(properties) ~= 'Created' then
            return util.requestError(
              ngx.HTTP_SERVICE_UNAVAILABLE,
              'HTTP service unavailable',
              'request failure')
          end
        end
      end
    end
  end
end

function putAsset( properties )
  ngx.log(ngx.INFO, 'PUT APP ASSET')
  local http          = require "resty.http"
  local httpc = http.new()
  local ok, err = httpc:connect( config.get('host'), config.get('port'))
  if not ok then 
    return util.requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end

  ngx.log(ngx.INFO, 'Connected to '  .. config.get('host') ..  ' on port '  .. config.get('port'))
  local res, err = httpc:request({
      version = 1.1,
      method = "PUT",
      path = properties.path,
      headers = {
        ["Authorization"] =  config.get('auth'),
        ["Content-Type"] = properties.mime
      },
      body = read( properties.temp ),
      ssl_verify = false
    })

  if not res then
    return util.requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'request failure')
  end
  ngx.log(ngx.INFO, 'Response status: [ '  .. res.status ..   ' '  .. res.reason .. ' ]'   )
  if res.has_body then
    body, err = res:read_body()
    if not body then
      ngx.say("failed to read body: ", err)
      return
    end
  end
   return res.reason
end

--[[
--  only log failures
--https://stackoverflow.com/questions/3237882/get-week-of-year-from-day-of-year
--ngx.var.domain
--]]--

function _M.proxyGetDelete( collection, resource )
  local http   = require "resty.http"
  local authorization = config.get('auth')
  local domain  = ngx.var.domain
  local host  = config.get('host')
  local port  = config.get('port')
  local contentType = 'application/xml'
  -- eXist rest server
  local dataPath = "/exist/rest/db/data/" .. domain  .. '/docs'
  local resPath  = dataPath .. '/' .. collection .. '/' .. resource
  local httpc = http.new()
  httpc:set_timeout(500)
  local msg = ''
  local ok, err = httpc:connect( host, port)
  if not ok then
    msg = 'eXist connection failure'
    ngx.log(ngx.INFO, msg )
     return util:requestError( ngx.HTTP_BAD_REQUEST,'bad request', msg)
   end
  msg = 'connected to ' .. host .. ' on port ' .. port
  ngx.log(ngx.INFO, msg )
  local method = ngx.req.get_method()
  msg =  method  .. ' resource "' ..  resource .. '" in "' .. collection .. '" collection'
  ngx.log(ngx.INFO, msg )
  httpc:set_timeout(2000)
  -- ngx.log(ngx.INFO, msg )
  httpc:proxy_response( httpc:request({
        ['version'] = 1.1,
        ['method'] = method,
        ['path'] = resPath,
        ['headers'] = {
          ["Authorization"] = authorization
        },
        ['ssl_verify'] = false
    }))
   httpc:set_keepalive()
end


function _M.putXML( collection, resource , data )
  local http   = require "resty.http"
  local authorization = config.get('auth')
  local domain  = ngx.var.domain
  local host  = config.get('host')
  local port  = config.get('port')
  local contentType = 'application/xml'
  local dataPath = "/exist/rest/db/data/" .. domain  .. '/docs'
  local putPath  = dataPath .. '/' .. collection .. '/' .. resource
  local httpc = http.new()
  local ok, err = httpc:connect( host, port)
  if not ok then
    msg = 'eXist connection failure'
    ngx.log(ngx.INFO, msg )
    return nil
  end
  local response, err = httpc:request({
      version = 1.1,
      method = "PUT",
      path = putPath,
      headers = {
        ["Authorization"] = authorization,
        ["Content-Type"] = contentType
      },
      body = data,
      ssl_verify = false
    })

  if not response then 
    msg = 'eXist response failure'
    ngx.log(ngx.INFO, msg )
    return nil
  end
  -- ngx.log(ngx.INFO, "PUT status: ", response.status)
  -- ngx.log(ngx.INFO, "PUT reason: ", response.reason)
  return response.reason
end

function _M.restQuery( txt )
  local config = require('grantmacken.config')
  local httpc   = require("resty.http").new()
  local authorization = config.get('auth')
  local domain  = ngx.var.domain
  local host  = config.get('host')
  local port  = config.get('port')
  local contentType = 'application/xml'
  local restPath = "/exist/rest/db"
  local msg = ''
  local body = nil
  local ok, err = httpc:connect(host, port)
  if not ok then 
    msg = "failed to connect to eXist"
    return util.requestError(ngx.HTTP_BAD_REQUEST,'bad request',msg)
  end
  local res, err = httpc:request({
      version = 1.1,
      method = "POST",
      path = restPath,
      headers = {
        ["Authorization"] = authorization,
        ["Content-Type"] = contentType
      },
      body =  txt,
      ssl_verify = false
    })
  if not res then
    msg = "eXist failed to respond "
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request', msg)
  end
  if res.status ~= 200 then
    msg = "eXist failed to respond OK to request"
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request', msg)
  end

  if res.has_body then
    body, err = res:read_body()
    if not body then
      msg = "eXist failed to return reponse body"
      return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request', msg )
    end
  end
  -- note eXist will return a body but body may be empty
  -- note body may be empty | a string | nil
  return body
end




return _M
