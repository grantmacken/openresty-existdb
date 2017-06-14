local _M = {}

--[[

webmention.lua
@see https://www.w3.org/TR/webmention

# lua modules used

@see https://github.com/openresty/lua-nginx-module
@see https://github.com/pintsized/lua-resty-http

# Receiving Webmentions

@see https://www.w3.org/TR/webmention/#receiving-webmentions

 - Receive POST Request

 - Request Verification
   - source and target valid URLs
   - source not same as target
   - target as valid resource
   - Webmention Verification

https://www.w3.org/TR/webmention/#h-webmention-verification

--]]

local modUtil = require('grantmacken.util')

function _M.processRequest()
  ngx.log( ngx.INFO, 'Process Request' )
  local method = modUtil.acceptMethods({
      'POST'
    })
  local contentType = modUtil.acceptContentTypes({
      'application/x-www-form-urlencoded'
    })
  processPostArgs()
end

function processPostArgs()
  ngx.log(ngx.INFO, ' process POST arguments ' )
  local msg = ''
  local args = {}
  ngx.req.read_body()
  local reqargs = require "resty.reqargs"
  local get, post, files = reqargs()
  if not get then
    msg = "failed to get post args: " ..  err
    return modUtil.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end

  local getItems = 0
  for k,v in pairs(get) do
    getItems = getItems + 1
  end

  local postItems = 0
  for k,v in pairs(post) do
    postItems = postItems + 1
  end

  if  getItems > 0 then
    ngx.log(ngx.INFO, ' - count post args ' .. getItems )
    args = get
  end

  if  postItems > 0 then
    ngx.log(ngx.INFO, ' - count post args ' .. postItems )
    args = post
  end

  ngx.log(ngx.INFO, ' - should have 2 args target and source ' )

  if modUtil.tablelength( args ) ~= 2 then
    msg = " failure: webmention SHOULD have 2 POST args 'source' and 'target'"
    ngx.log(ngx.INFO, msg )
    return modUtil.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end
  ngx.log(ngx.INFO, 'receiver SHOULD verify the parameters' )
  modUtil.acceptFormArgs( args , { 'source', 'target'})

  -- Request Verification

  ngx.log(ngx.INFO, 'receiver MUST check that source and target are valid URLs' )
  if not isURL( args['source'] ) then
    msg = 'source "' .. args['source']  .. '" MUST be a valid url'
    ngx.log(ngx.INFO, msg)
    return modUtil.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end

  if not isURL( args['target'] ) then
    msg = 'target "' .. args['target']  .. '" MUST be a valid url'
    ngx.log(ngx.INFO, msg)
    return modUtil.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end

  ngx.log(ngx.INFO,'receiver MUST reject the request if the source URL is the same as the target URL' )
  if  args['target']  ==  args['source'] then
    msg = 'the source URL is the same as the target URL'
    ngx.log(ngx.INFO, msg)
    return modUtil.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  else
    msg = ' - Goody Gumdrops: the source URL is NOT the same as the target URL'
    ngx.log(ngx.INFO, msg)
  end

  ngx.log(ngx.INFO,
    'receiver SHOULD check that target is a valid resource for which it can accept Webmention' )
  if isValidResource( args['target'] ) then
    msg = ' - Yippee Do Da: target is a valid resource on my site'
    ngx.log(ngx.INFO, msg)
  else
    msg = 'failure target is NOT a valid resource on my site'
    ngx.log(ngx.INFO, msg)
    return modUtil.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end
  ngx.log(ngx.INFO,
    'Webmention Verification' )
  ngx.log(ngx.INFO,
    '=======================' )

  -- Webmention Verification
  -- Webmention verification SHOULD be handled asynchronously to prevent DoS (Denial of Service) attacks
  --  If the receiver is going to use the Webmention in some way ...
  --  -  MUST perform an HTTP GET request on source
  --  - SHOULD limit the number of redirects it follows
  --  - receiver SHOULD include an HTTP Accept header 

   local targRes    = getSource( args['source'], args['target']  )

  -- if targRes.has_body then
  --  local body, err = targRes:read_body()
  --   if not body then
  --     return modUtil.requestError(
  --       ngx.HTTP_BAD_REQUEST,
  --       'bad request',
  --       'connection failure')
  --   end

  --   ngx.say( body )
  -- end
  -- local targStored = storeSource( targRes )

  -- local concatTargSrc = args['source'] ..  args['target']
  -- local resID = createResourceID( concatTargSrc )

  -- ngx.say( resID )

   -- -  source URL was malformed or is not a supported URL scheme (e.g. a mailto: link)
   -- -  source URL not found
   --
   -- does the source document mention the target 
   -- - source URL does not contain a link to the target URL
   -- then
   -- MAY publish content from the source page on the target page

end

function getSource( source , target )
  local http = require "resty.http"
  local httpc = http.new()
  local msg = ''
  local scheme, host, port, path = unpack(httpc:parse_uri(source))
  local ok, err = httpc:connect( host, port )
  if not ok then
    msg = 'source URL not found - failed to connect'
    return modUtil.requestError(
      ngx.HTTP_BAD_REQUEST,
      'HTTP bad request',
      msg)
  end

  ngx.log(ngx.INFO, 'Connected to '  .. host ..  ' on port '  .. port)
  if scheme == 'https' then 
    -- 4 sslhandshake opts
    local reusedSession = nil -- defaults to nil
    local serverName = host    -- for SNI name resolution
    local sslVerify = false  -- boolean if true make sure the directives set
    -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth 
    local sendStatusReq = '' -- boolean OCSP status request
    local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
    if not shake then
      msg = "source URL not found - failed to do SSL handshake: ", err
      return modUtil.requestError(
        ngx.HTTP_BAD_REQUEST,
        'HTTP bad request',
        msg)
    end
    ngx.log(ngx.INFO, "SSL Handshake Completed: "  ..type(shake))
  end

  httpc:set_timeout(2000)
  local response, err = httpc:request({
      ['version'] = 1.1,
      ['method'] = "GET",
      ['path'] = path,
      ['headers'] = {
        ["Host"] =  host,
        ["User-Agent"] =  'Mozilla/5.0' ,
        ["Accept"] =  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        ["Connection"] =  'keep-alive',
        ["DNT"] =  '1',
        ["Cache-Control"] =  'max-age=0',
        ["Upgrade-Insecure-Requests"] =  '1',
      },
      ['ssl_verify'] = sslVerify
    })
  if not response then
    msg = "source URL not found - ailed to complete request: ", err
    return requestError(ngx.HTTP_BAD_REQUEST,'bad request', msg ) 
  end
  ngx.log(ngx.INFO, "Request Response Status: " .. response.status)
  ngx.log(ngx.INFO, "Request Response Reason: " .. response.reason)
  local body = ''
  if response.has_body then
    body, err = response:read_body()
    if not body then
      msg = "source URL not found - failed to read body: " ..  err
      return modUtil.requestError(
        ngx.HTTP_BAD_REQUEST,
        'HTTP bad request',
        msg)
    end
  end
  -- detirmine content-type from response header
  if response.headers['Content-Type']  ~= nil then
    ngx.log(ngx.INFO, "Request Response Content-Type: " .. response.headers['Content-Type'] )
  else
    local msg =  'source URL not found - can not determine content type'
    return modUtil.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request ' ,
      msg )
  end

  if response.headers['Content-Encoding'] ~= nil then
    ngx.log(ngx.INFO, "Request Response Content-Encoding: " .. response.headers['Content-Encoding'])
    ngx.log(ngx.INFO, "TODO!:  if gzip etc might need to decode" )
  end

  local contentTypeHeader = response.headers['Content-Type']
  -- TODO!  only handles text/html content
  -- The receiver SHOULD use per-media-type rules to determine whether the source document mentions the targe
  local from, to, err = ngx.re.find(contentTypeHeader ,"(text/html|text/plain)")
  if from then
    local contentType =  string.sub( contentTypeHeader, from, to )
    -- ngx.log(ngx.INFO, " - ok we can handle : " .. contentType)
    -- ngx.log(ngx.INFO, " - check if source content mentions target" )
    -- ngx.log(ngx.INFO, " - i.e.  somewhere in 'source content'  there is a mention of a resource ( target ) on my site" )
    -- ngx.log(ngx.INFO, " - note: target has already validated as a resource on my site" )
    -- the receiver should look for properties whose values are an exact match for the URL
    ---TODO!
    --The receiver SHOULD use per-media-type rules to determine whether the 
    -- source document mentions the target URL. For example, in an [ HTML5] document, 
    -- the receiver should look for <a href="*">, <img href="*">, <video src="*"> and 
    -- other similar links. In a JSON ([RFC7159]) document, the receiver should look 
    -- for properties whose values are an exact match for the URL. If the document is 
    -- plain text, the receiver should look for the URL by searching for the string.
    -- ngx.log(ngx.INFO, " - initial check is to see if target string is in source body text" )
    ngx.log(ngx.INFO, "source document MUST have an exact match of the target URL")
    if findTargetInSource( body , target ) then
      ngx.log(ngx.INFO, " - Okey Dokey - found target body text in source body text" )
      local concatTargSrc = source ..  target
      local resource = createResourceID( concatTargSrc )
      local collection = 'mentions'
      local data =  extractSource( ngx.encode_base64( body ))
      local reason = require('grantmacken.eXist').putXML( collection, resource , data )
      if reason ~= nil then
        ngx.log(ngx.INFO, "stored 'source' body text as XML into eXist" )
        ngx.log(ngx.INFO, "stored 'source' will be in the 'docs/mentions' collection" )
      end
    else
      local msg =  'source URL does not contain a link to the target URL.'
      return modUtil.requestError(
        ngx.HTTP_BAD_REQUEST,
        'bad request',
        msg )
    end
  else
    if err then
      local msg =  'source URL not found - ' .. err .. ' - can not proccess ' .. contentTypeHeader
      return modUtil.requestError(
        ngx.HTTP_BAD_REQUEST,
        'bad request',
        msg )
    end
    local msg =  'source URL not found - can not proccess ' .. contentTypeHeader
    return modUtil.equestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request ' ,
      msg )
  end
  -- ngx.say( extractSource( ngx.encode_base64( body ) ))
end

 function findTargetInSource( srcBody, target )
   ngx.log(ngx.INFO, "In source text look for string [ " .. target  .. ' ] ' )
   ngx.log(ngx.INFO, 'NOTE have not parsed source str' )
   local isFound = false
   local regEx = '(' .. target .. ')'
   local from, to, err = ngx.re.find( srcBody ,regEx )
   if from then
     local link =  string.sub( srcBody, from, to )
     ngx.log(ngx.INFO, ' - OK target link found: ' .. link )
     isFound = true
   else
     if err then
       ngx.log(ngx.INFO, "error: ", err)
     end
     ngx.log(ngx.INFO, "not matched!")
   end
   return isFound
 end

function extractSource( binary )
  local restPath  = '/exist/rest/db'
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    try { util:parse-html(util:base64-decode("]] .. binary.. [[")) }
    catch *{()}
     ]] ..']]>' .. [[
    </text>
  </query>
]]
  --  ngx.log(ngx.INFO, 'constructed txt')
  --  ngx.say(txt)
  local responseBody =  require('grantmacken.eXist').restQuery( txt )
  ngx.log(ngx.INFO, "body: ", responseBody)
  ngx.log(ngx.INFO, "body: ", type( responseBody))

  return responseBody
end

function isValidResource( url )
  local config = require('grantmacken.config')
  local domain  = config.get('domain')
  ngx.log(ngx.INFO, 'target URL: ' .. url )
  local msg = ''
   -- lua-modules/util.lua
  local dbID = modUtil.extractID( url )
  ngx.log(ngx.INFO, type(dbID) )
  if not dbID then
    return false
  end
  ngx.log(ngx.INFO, 'extracted ID: ' .. dbID )
  -- ngx.log(ngx.INFO, url)
  local contentType = 'application/xml'
  local restPath  = '/exist/rest/db'
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    try { doc-available( "xmldb:exist:///db/data/]] .. domain  .. '/docs/posts/' .. dbID .. [[") }
    catch *{()}
     ]] ..']]>' .. [[
    </text>
  </query>
]]

  local exResult = require('grantmacken.eXist').restQuery( txt )
  -- expect boolean
  if exResult == 'true' then
    return true
  else
    return false
  end
end

function createResourceID( str )
  local config = require('grantmacken.config')
  local domain  = config.get('domain')
  local restPath  = '/exist/rest/db'
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace muURL="http://markup.nz/#muURL" at "xmldb:exist:///db/apps/]] .. domain  .. [[/modules/lib/muURL.xqm";
    try { muURL:urlHash( "]] .. str.. [[") }
    catch *{()}
    ]] ..']]>' .. [[
    </text>
  </query>
]]
  --  ngx.log(ngx.INFO, 'constructed txt')
  --  ngx.say(txt)
  local responseBody =  require('grantmacken.eXist').restQuery( txt )
  ngx.log(ngx.INFO, "body: ", responseBody)
  --ngx.log(ngx.INFO, "body: ", type( responseBody))
  return responseBody
end

function isURL( url )
  ngx.log(ngx.INFO, url)
  local config = require('grantmacken.config')
  local domain  = config.get('domain')
  local contentType = 'application/xml'
  local restPath  = '/exist/rest/db'
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace muURL="http://markup.nz/#muURL" at "xmldb:exist:///db/apps/]] .. domain  .. [[/modules/lib/muURL.xqm";
    try { muURL:meetsAcceptableCriteria(  "]] .. url .. [[" ) }
    catch *{()}
     ]] ..']]>' .. [[
    </text>
  </query>
]]
  local exResult = require('grantmacken.eXist').restQuery( txt )
  -- expect boolean
  if exResult == 'true' then
    return true
  else
    return false
  end
end

return _M
