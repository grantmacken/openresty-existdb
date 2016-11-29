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

local cfg = {
port = 8080,
host = '127.0.0.1',
auth = 'Basic ' .. os.getenv("EXIST_AUTH") 
}
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

function extractID( url )
  -- short urls https://gmack.nz/xxxxx
  local sID, err = require("ngx.re").split(url, "([na]{1}[0-9A-HJ-NP-Z_a-km-z]{4})")[2]
  if err then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  return sID
end



function getPostsPath()
  return '/db/data/' ..  ngx.var.site .. '/docs/posts/'
end

  -- generic exist endpoint for talking to eXistdb 

function _M.processRequest()
 ngx.say('OK')
 ngx.say( ngx.var.resources )
 ngx.say( ngx.var.site)
end

function getRequest2( query )
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local host = '127.0.0.1'
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
  local host = '127.0.0.1'
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
  local host = '127.0.0.1'
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
  local host = '127.0.0.1'
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

--[[

function _M.createXML( data )
  local xml = require 'xml'
  local http = require "resty.http"
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local contentType = 'application/xml'
  local domain   = ngx.var.http_Host
  local resource = xml.find(data, 'id')[1]
  local kindOfPost = xml.find(data, 'entry').kind
  local appPath  = "/exist/restxq/db/apps/" .. domain  
  local endpoint  = "micropub"
  local endpointPath  = appPath .. '/' .. colPath
  local host = '127.0.0.1'
  local port = 8080

  --  ngx.say(putPath)
  --  ngx.say(xml.dump(data))

  local httpc = http.new()
  local ok, err = httpc:connect(host, port)
  if not ok then
    ngx.say("failed to connect to ",host ," ",  err)
    return
  end

  local res, err = httpc:request({
      version = 1.1,
      method = "POST",
      path = endpointPath,
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
 --  ngx.say("status: ", res.status)
 --  ngx.say("reason: ", res.reason)
 --  ngx.say("has body: ", res.has_body)

  if res.has_body then
    body, err = res:read_body()
    if not body then
      ngx.say("failed to read body: ", err)
      return
    end
  end
  ngx.status = ngx.HTTP_CREATED
  --ngx.header.content_type = 'text/plain'
  ngx.header.location = 'http://' .. domain .. '/' .. resource 
  
end

--   if res.has_body then
--     body, err = res:read_body()
--     if not body then
--       ngx.say("failed to read body: ", err)
--       return
--     end
--   -- ngx.say(type(body))
--   -- ngx.say(body)
--   end
--]]

function _M.replaceProperty( uri, property, item )
  local url = require('net.url').parse(uri)
  local resource = string.gsub(url.path, "/", "")
  local xml = require 'xml'
  local contentType = 'application/xml'
  local domain   = ngx.var.http_Host
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local docPath   = '/db/data/' .. domain .. '/docs/posts/' .. resource
  local xmlNode = {} 
  -- TODO only allow certain properties
  -- ngx.say( uri )
  -- ngx.say( property )
  -- ngx.say( item )
  if property == 'content' then
    xmlNode = { xml = property, type = 'text', item } 
  else
    xmlNode = { xml = property, item } 
  end

  -- ngx.say(xml.dump(xmlNode))

  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    let $node := ]] .. xml.dump(xmlNode) .. [[

    let $item := ']] .. item .. [['
    return
    if ( exists( $document/entry/]] .. property .. [[)) then (
      update replace $document/entry/]] .. property .. [[ with $node )
    else (
      update insert $node into $document/entry
    )

    ]] ..']]>' .. [[ 
    </text>
  </query>
]]
  --  ngx.say(txt)
  local response =  sendMicropubRequest( restPath, txt )
  ngx.exit(response.status)
  ngx.say("status: ", response.status)
  ngx.say("reason: ", response.reason)
  ngx.exit(response.status)
end

function _M.addProperty( uri, property, item )
  local url = require('net.url').parse(uri)
  local resource = string.gsub(url.path, "/", "")
  local xml = require 'xml'
  local contentType = 'application/xml'
  local domain   = ngx.var.http_Host
  -- TODO only allow certain properties
  ngx.say( uri )
  ngx.say( property )
  ngx.say( item )
  local xmlNode = { xml = property, item }
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local docPath   = '/db/data/' .. domain .. '/docs/posts/' .. resource
  ngx.say(xml.dump(xmlNode))
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    let $node := ]] .. xml.dump(xmlNode) .. [[

    let $item := ']] .. item .. [['
    return
    if ($document/entry/]] .. property .. [[  = $node ) then (
      update replace $document/entry/]] .. property .. [[[./string() eq $item]  with $node )
    else (
      update insert $node into $document/entry
    )

    ]] ..']]>' .. [[ 
    </text>
  </query>
]]
  ngx.say(txt)
  local response =  sendMicropubRequest( restPath, txt )
  ngx.say("status: ", response.status)
  ngx.say("reason: ", response.reason)

  ngx.status = ngx.HTTP_OK
end

function _M.removeProperty( uri, property)
  local url = require('net.url').parse(uri)
  local resource = string.gsub(url.path, "/", "")
  local xml = require 'xml'
  local contentType = 'application/xml'
  local domain   = ngx.var.site
  -- TODO only allow certain properties
  -- ngx.say( uri )
  -- ngx.say( property )
  -- ngx.say( domain )
  -- local xmlNode = { xml = property }
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local docPath   = '/db/data/' .. domain .. '/docs/posts/' .. resource
  -- ngx.say(xml.dump(xmlNode))
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    return
    if ( exists($document//]] .. property .. [[ )) 
      then ( update delete $document//]] .. property .. [[ )
    else ( )
    ]] ..']]>' .. [[ 
    </text>
  </query>
]]
  -- ngx.say(txt)
  local response =  sendMicropubRequest( restPath, txt )
  return response.reason
end



function _M.removePropertyItem( uri, property, item )
  local contentType = 'application/xml'
  local domain      = ngx.var.site
  local resource    = extractID( uri) 
  -- TODO only allow certain properties
  -- ngx.say( resource )
  -- ngx.say( property )
  -- ngx.say( item )
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local docPath   = '/db/data/' .. domain .. '/docs/posts/' .. resource
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    let $item := ']] .. item .. [['
    let $oldString := if($document/entry/]] .. property .. [[/text()) then (
       $document/entry/]] .. property .. [[/string())
    else ( )
    let $newString := if ( empty( $oldString )) then ( )
    else(
        let $tokens := tokenize( $oldString, ' ' ) 
        let $filtered := filter( $tokens , function($token){not( $token eq $item )})
        return
        string-join($filtered,' ')
    )
    return
    if ( empty( $oldString )) then ( )
    else ( update value $document/entry/]] .. property .. [[ with $newString )
    ]] ..']]>' .. [[ 
    </text>
  </query>
]]
  -- ngx.say(txt)

  local response =  sendMicropubRequest( restPath, txt )
  return response.reason
end

--[[
deleting and undeleting posts
moves posts to and from a recycle collection ( like a trash/recycle bin )
on windows
--]]

function _M.deletePost( uri)
  local contentType = 'application/xml'
  local domain      = ngx.var.site
  local resource    = extractID( uri) 
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local sourceCollection = '/db/data/' .. domain .. '/docs/posts'
  local targetCollection = '/db/data/' .. domain .. '/docs/recycle'
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $sourceCollection := "]] .. sourceCollection .. [["
    let $targetCollection := "]] .. targetCollection .. [["
    let $resource         := "]] .. resource .. [["
    let $docPath          := $sourceCollection || '/' || $resource
    return
    if (exists($docPath)) then (
     xmldb:move( $sourceCollection, $targetCollection, $resource)
    )
    else ( )
    ]] ..']]>' .. [[ 
    </text>
  </query>
]]
  -- ngx.say(txt)
  local response =  sendMicropubRequest( restPath, txt )
  -- ngx.say("status: ", response.status)
  -- ngx.say("reason: ", response.reason)
  ngx.exit(response.status )

end

function _M.undeletePost( uri)
  local url = require('net.url').parse(uri)
  local resource = string.gsub(url.path, "/", "")
  local contentType = 'application/xml'
  local domain   = ngx.var.http_Host
  ngx.say( uri )
  local xmlNode = { xml = property, item }
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local sourceCollection = '/db/data/' .. domain .. '/docs/recycle'
  local targetCollection = '/db/data/' .. domain .. '/docs/posts'
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $sourceCollection := "]] .. sourceCollection .. [["
    let $targetCollection := "]] .. targetCollection .. [["
    let $resource         := "]] .. resource .. [["
    let $docPath          := $sourceCollection || '/' || $resource
    return
    if (exists($docPath)) then (
     xmldb:move( $sourceCollection, $targetCollection, $resource)
    )
    else ( )

    ]] ..']]>' .. [[ 
    </text>
  </query>
]]
  ngx.say(txt)
   local response =  sendMicropubRequest( restPath, txt )
   ngx.say("status: ", response.status)
   ngx.say("reason: ", response.reason)
end

function _M.fetchMediaLinkDoc( )
  -- ngx.say( 'Fetch Media Link Doc' )
  local http = require "resty.http"
  local authorization = cfg.auth 
  local domain        = ngx.var.site
  -- ngx.say( ngx.var.uri )
  -- ngx.say( ngx.var.request_uri )
  local docPath  = "/exist/rest/db/data/" .. domain .. '/docs' ..  ngx.var.uri
  -- ngx.say( docPath )
  local httpc = http.new()
  -- local scheme, host, port, path, query? = unpack(httpc:parse_uri(uri, false))
  local ok, err = httpc:connect(cfg.host, cfg.port)
  if not ok then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  httpc:set_timeout(2000)
  httpc:proxy_response( httpc:request({
        version = 1.1,
        method = "GET",
        path = docPath,
        headers = {
          ["Content-Type"] = "application/xml",
          ["Authorization"] = authorization 
        },
        ssl_verify = false
    }))
  httpc:set_keepalive()
end

function _M.fetchPostsDoc( url )
  -- ngx.say( 'Fetch Posts Doc' )
 --  local ngx_re = require "ngx.re"
  local sID, err = require("ngx.re").split(url, "([na]{1}[0-9A-HJ-NP-Z_a-km-z]{4})")[2]
  -- ngx.say(sID)
  -- ngx.exit( 200 )
  local http = require "resty.http"
  local authorization = cfg.auth 
  local domain        = ngx.var.site
  -- ngx.say( ngx.var.uri )
  -- ngx.say( ngx.var.request_uri )
  local docPath  = "/exist/rest/db/data/" .. domain .. '/docs/posts/' .. sID 
  -- ngx.say( docPath )
  local httpc = http.new()
  -- local scheme, host, port, path, query? = unpack(httpc:parse_uri(uri, false))
  local ok, err = httpc:connect(cfg.host, cfg.port)
  if not ok then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  httpc:set_timeout(2000)
  httpc:proxy_response( httpc:request({
        version = 1.1,
        method = "GET",
        path = docPath,
        headers = {
          ["Content-Type"] = "application/xml",
          ["Authorization"] = authorization 
        },
        ssl_verify = false
    }))
  httpc:set_keepalive()
end

function _M.putMedia( part_body, resource, mime  )
  local http = require "resty.http"
  local authorization = cfg.auth 
  local domain        = ngx.var.site
  -- ngx.say( contentType )
  local dataPath = "/exist/rest/db/data/" .. domain
  local colPath  = "media"
  local putPath  = dataPath .. '/' .. colPath .. '/' .. resource

  local httpc = http.new()
  local ok, err = httpc:connect(cfg.host, cfg.port)
  if not ok then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end

  local res, err = httpc:request({
      version = 1.1,
      method = "PUT",
      path = putPath,
      headers = {
        ["Authorization"] = authorization,
        ["Content-Type"] = mime
      },
      body = part_body ,
      ssl_verify = false
    })
  if not res then
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'request failure')
  end
  -- ngx.say("status: ", res.status)
  -- ngx.say("reason: ", res.reason)
  -- ngx.say("has body: ", res.has_body)

  if res.has_body then
    body, err = res:read_body()
    if not body then
      ngx.say("failed to read body: ", err)
      return
    end
  end
  return res.reason
 -- ngx.header.location = 'http://' .. domain .. '/_media/' .. resource 
 --  ngx.status = ngx.HTTP_CREATED
 -- ngx.header.content_type = 'text/plain'
end 

function sendMicropubRequest( restPath, txt  )
  local http = require "resty.http"
  local authorization = cfg.auth
  local contentType = 'application/xml'
  -- ngx.say( txt )

  local httpc = http.new()
  local ok, err = httpc:connect(cfg.host, cfg.port)
  if not ok then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
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
    ngx.say("failed to request: ", err)
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  return res
end

function isMedia( )
  return xml.find(data,'media')
end

function _M.putXML( collection,  data )
  local xml = require 'xml'
  local http = require "resty.http"
  local authorization = cfg.auth
  local contentType = 'application/xml'
  local domain   = ngx.var.http_Host
  local resource = xml.find(data, 'id')[1]
  --local kindOfPost = xml.find(data, 'entry').kind
  local dataPath = "/exist/rest/db/data/" .. domain  .. '/docs'
  -- store without extension
  local putPath  = dataPath .. '/' .. collection .. '/' .. resource

  local httpc = http.new()
  local ok, err = httpc:connect(cfg.host, cfg.port)
  if not ok then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
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
 --  ngx.say("status: ", res.status)
 --  ngx.say("reason: ", res.reason)
 --  ngx.say("has body: ", res.has_body)

  if res.has_body then
    body, err = res:read_body()
    if not body then
      ngx.say("failed to read body: ", err)
      return
    end
  end
  return res.reason
end

function deleteRequest( path )
  local http = require "resty.http"
  local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
  local domain = ngx.var.http_Host
  local appPath  = "/exist/rest/db/apps/" .. domain
  local deletePath = appPath .. '/' .. path 
  local host = '127.0.0.1'
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

-- function store( query )
--   local authorization = 'Basic ' .. os.getenv("EXIST_AUTH") 
--   local domain = ngx.var.http_Host
--   local restPath  = '/exist/rest/db/apps/' .. domain
--   local colPath  = "/db/apps/" .. domain .. '/data/posts'
--   local resource = 'test.xml'
--   local xml = require 'xml'
--   local txt = [[
-- <query xmlns='http://exist.sourceforge.net/NS/exist' wrap='no'>
--   <text><![CDATA[
-- xquery version "3.1";
-- xmldb:store(']] .. colPath .. [[',']]  .. resource .. [[',<entry/> )
-- ]] .. ']]></text></query>'

--   ngx.say(txt)
--   -- local data = xml.load(txt)
--   -- ngx.say(xml.dump(data))
--     -- local properties = {
--     --   xml = 'properties',{
--     --     xml = 'property', name = 'method', value = 'json'
--     --   }
--     -- }
-- -- local  data = { 
-- -- xml = 'query' , 
-- -- xmlns = 'http://exist.sourceforge.net/NS/exist',
-- -- wrap = 'no', {
-- --   xml = 'text', txt
-- --     }
-- --   } 
--   -- return
--   local http = require "resty.http"
--   local host = '127.0.0.1'
--   local port = 8080

--   local httpc = http.new()
--   local ok, err = httpc:connect(host, port)
--   if not ok then
--     ngx.say("failed to connect to ",host ," ",  err)
--     return
--   end

--   local res, err = httpc:request({
--       version = 1.1,
--       method = "POST",
--       path = restPath,
--       headers = {
--         ["Authorization"] = authorization 
--       },
--       body =  txt,
--       ssl_verify = false
--     })
--   if not res then
--     ngx.say("failed to request: ", err)
--     return
--   end

--   ngx.say("status: ", res.status)
--   ngx.say("reason: ", res.reason)
--   ngx.say("has body: ", res.has_body)

--   if res.has_body then
--     body, err = res:read_body()
--     if not body then
--       ngx.say("failed to read body: ", err)
--       return
--     end
--   end
--     ngx.say(body)
-- end




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
  -- see intro
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
