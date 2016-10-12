
local _M = {}

--[[
 my module for interacting with eXist database
 conveniance queries
  GET requests
   path path to xml collection or a resource contained in apps/myApp dir
       eg path=repo.xml
       returns xml string
   gq  simple function  _query to db 
       returns a string
   xq  execute a xquery script located apps/myApp/modules/xq dir 
   TODO!

   POST requests

   pq  a post query




--]]
--
--UTILITY TODO move to utility.lua
function requestError( status, msg ,description)
  ngx.status = status
  ngx.header.content_type = 'application/json'
  local json = cjson.encode({
      error  = msg,
      error_description = description
    })
  ngx.print(json)
  ngx.exit(status)
end

function getRequest2( query )
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local host = 'localhost'
  local port = 8080

  local url = require "net.url"
  local http = require "resty.http"
  local httpc = http.new()
  httpc:set_timeout(6000) 
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end
  httpc:set_timeout(2000)
  httpc:proxy_response( httpc:request({
        version = 1.1,
        method = "GET",
        path = query,
        headers = {
          ["Authorization"] = authorization 
        },
        ssl_verify = false
    }))
  httpc:set_keepalive()
end

function pathQuery( path )
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local domain = ngx.var.http_Host
  local appPath  = "/exist/rest/db/apps/" .. domain
  local reqPath = appPath .. '/' .. path
  local http = require "resty.http"
  local host = 'localhost'
  local port = 8080
  local httpc = http.new()
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end
  local res, err = httpc:request({
      version = 1.1,
      method = "GET",
      path = reqPath,
      headers = {
        ["Authorization"] = authorization 
      },
      ssl_verify = false
    })
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
  end
    ngx.say(body)
  end

function getQuery( query )
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local domain = ngx.var.http_Host
  local appPath  = "/exist/rest/db/apps/" .. domain
  local queryString = '_wrap=no&_query=' ..  query 
  local reqPath = appPath .. '?' .. queryString
  local http = require "resty.http"
  local host = 'localhost'
  local port = 8080
  local httpc = http.new()
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end
  local res, err = httpc:request({
      version = 1.1,
      method = "GET",
      path = reqPath,
      headers = {
        ["Authorization"] = authorization 
      },
      ssl_verify = false
    })
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
  end
    ngx.say(body)
  end

function postQuery( query )
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local domain = ngx.var.http_Host
  local appPath  = "/exist/rest/db/apps/" .. domain 
  local  xml = require 'xml'
  local txt  =   [[
xquery version "3.1";
import module namespace archive = "http://gmack.nz/#archive" at "xmldb:exist://db/apps/]] .. domain .. [[/modules/lib/archive.xqm";
let $x := format-date(current-date(), "[Y0001]-[M01]-[D01]")

return (
]] .. query .. [[
)
]]

    -- local properties = {
    --   xml = 'properties',{
    --     xml = 'property', name = 'method', value = 'json'
    --   }
    -- }
  local  data = { 
  xml = 'query' , 
  xmlns = 'http://exist.sourceforge.net/NS/exist',
  wrap = 'no', {
    xml = 'text', txt
    }
  } 
  ngx.say(xml.dump(data))

  local http = require "resty.http"
  local host = 'localhost'
  local port = 8080

  local httpc = http.new()
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end

  local res, err = httpc:request({
      version = 1.1,
      method = "POST",
      path = appPath,
      headers = {
        ["Authorization"] = authorization 
      },
      body =  xml.dump(data),
      ssl_verify = false
    })
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
  end
    ngx.say(body)
end

function _M.PutXML( data )
  local xml = require 'xml'
  local http = require "resty.http"
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local contentType = 'application/xml'
  local domain   = ngx.var.http_Host
  local appPath  = "/exist/rest/db/apps/" .. domain
  local colPath  = "docs/posts"
  local resource = xml.find(data, 'id')[1]
  local putPath  = appPath .. '/' .. colPath .. '/' .. resource .. '.xml'
  local host = 'localhost'
  local port = 8080

   ngx.say(putPath)
   ngx.say(xml.dump(data))

  local httpc = http.new()
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end

  local res, err = httpc:request({
      version = 1.1,
      method = "PUT",
      path = putPath,
      headers = {
        ["Authorization"] = authorization,
        ["Content-Type"] = contentType
      },
      body =  xml.dump(data),
      ssl_verify = false
    })
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
  end
end

function deleteRequest( path )
  local http = require "resty.http"
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local domain = ngx.var.http_Host
  local appPath  = "/exist/rest/db/apps/" .. domain
  local deletePath = appPath .. '/' .. path 
  local host = 'localhost'
  local port = 8080
  ngx.say(deletePath)

  local httpc = http.new()
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end

  local res, err = httpc:request({
      version = 1.1,
      method = "DELETE",
      path = deletePath,
      headers = {
        ["Authorization"] = authorization 
      },
      ssl_verify = false
    })
  if not res then
    ngx.say("failed to request: ", err)
    return
  end
  ngx.say("status: ", res.status)
  ngx.say("reason: ", res.reason)
end

function store( query )
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local domain = ngx.var.http_Host
  local restPath  = '/exist/rest/db/apps/' .. domain
  local colPath  = "/db/apps/" .. domain .. '/data/posts'
  local resource = 'test.xml'
  local xml = require 'xml'
  local txt = [[
<query xmlns='http://exist.sourceforge.net/NS/exist' wrap='no'>
  <text><![CDATA[
xquery version "3.1";
xmldb:store(']] .. colPath .. [[',']]  .. resource .. [[',<entry/> )
]] .. ']]></text></query>'

  ngx.say(txt)
  -- local data = xml.load(txt)
  -- ngx.say(xml.dump(data))
    -- local properties = {
    --   xml = 'properties',{
    --     xml = 'property', name = 'method', value = 'json'
    --   }
    -- }
-- local  data = { 
-- xml = 'query' , 
-- xmlns = 'http://exist.sourceforge.net/NS/exist',
-- wrap = 'no', {
--   xml = 'text', txt
--     }
--   } 
  -- return
  local http = require "resty.http"
  local host = 'localhost'
  local port = 8080

  local httpc = http.new()
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end

  local res, err = httpc:request({
      version = 1.1,
      method = "POST",
      path = restPath,
      headers = {
        ["Authorization"] = authorization 
      },
      body =  txt,
      ssl_verify = false
    })
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
  end
    ngx.say(body)
end

function _M.exist()
  -- proccess application 'application/x-www-form-urlencoded' requests
  local method = ngx.req.get_method()
  local contentType = ngx.req.get_headers()["Content-Type"]
  local acceptContentType = {}
  acceptContentType['application/x-www-form-urlencoded'] = true
  acceptContentType['application/json'] = true
  acceptContentType['application/xml'] = true
  -- local acceptContentType = {
  --   'x-www-form-urlencoded' = true,
  --   'json' = true, 
  --   'xml' = true 
  -- }

   ngx.say(contentType)
   ngx.say(method)
   

   if not acceptContentType[contentType]  then
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      'endpoint only accepts content-type of either xml, json or x-www-form-urlencoded')
   end

  ngx.req.read_body()
  local args, err = ngx.req.get_post_args()
  if not args then
    local args = ngx.req.get_uri_args()
    return
  end
  for key, val in pairs(args) do
    if type(val) == "table" then
      ngx.say(key, ": ", table.concat(val, ", "))
    else
      ngx.say(key, ": ", val)
    end
  end
--
-- conveniance queries
--  GET requests
--   path path to xml collection or a resource contained in apps/myApp dir
--       eg path=repo.xml
--       returns xml string
--   gq  simple function  _query to db 
--       returns a string
--   xq  execute a xquery script located apps/myApp/modules/xq dir 
--   TODO!
--
--   POST requests
--
--   pq  a post query
--
--

  if args['path'] then
    pathQuery( args['path'])
  elseif args['gq'] then
    getQuery( args['gq'])
  elseif args['pq'] then
    postQuery( args['pq'] )
  elseif args['h'] then
    putRequest()
  elseif args['delete'] then
    deleteRequest(args['delete'])
  elseif args['store'] then
    store()
  end
end

return _M
