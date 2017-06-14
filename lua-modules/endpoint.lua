local _M = {}
--[[
@see https://www.w3.org/TR/webmention/#sender-discovers-receiver-webmention-endpoint
@see https://webmention.rocks/
@see https://github.com/golgote/neturl
--]]

local modUtil = require('grantmacken.util')
local cfg     = require('grantmacken.config')
local http = require "resty.http"

--[[
sender discovers receiver webmention endpoint
----------------------------------------------

before we can send a webmention we examine the target and try to
discover the webmention endpoint
@see https://www.w3.org/TR/webmention/#sender-discovers-receiver-webmention-endpoint
]]--

function _M.discoverWebmentionEndpoint( target )
  ngx.log (ngx.INFO, '---------------------------' )
  ngx.log(ngx.INFO, 'Discover Webmention Endpoint')
  ngx.log (ngx.INFO, '---------------------------' )
  ngx.log(ngx.INFO, 'Target: '   .. target        )
  local linkURL = resStatus(target, nil)
  if type( linkURL ) == 'string' then
    ngx.log(ngx.INFO, 'Discovered Webmention Endpoint')
  else
    linkURL =  nil
  end
  return linkURL
end

function resStatus( target, res )
  local util = require('grantmacken.util')
  if res == nil then
    ngx.log(ngx.INFO, "Initial Request: " .. target  )
    res, err = util.fetch( target )
    ngx.log(ngx.INFO, "Initial Response: " .. res.reason )
  end
  if res.status == 302 then
    ngx.log(ngx.INFO, 'First Response Redirect: ' .. res.status  )
    local location = resolveRedirectLocation( target, res )
    if location ~= nil then
      res, err = util.fetch( target )
      ngx.log(ngx.INFO, "Redirect Response: " .. res.reason )
    end
  end
  if res.status == 200 then
    ngx.log(ngx.INFO, "Response OK: " .. res.status  )
    linkURL = resHeaders( target, res )
    if linkURL ~= nil then
      ngx.log(ngx.INFO, "Return linkURL: " .. linkURL)
    else
      linkURL = resBody( target, res )
    end
  end
  return linkURL
 end

function resolveRedirectLocation(  target, res )
  ngx.log(ngx.INFO, " - redirect " )
  local httpc = require('resty.http').new()
  local scheme, host, port, path = unpack(httpc:parse_uri(target))
  local base = scheme .. '://' .. host
  local location =  res.headers['Location']
  if location ~= nil then
    if string.sub( location, 1, 1 ) == '/' then
      location = base .. location
    end
    if string.sub( location, 1, 4 ) ~= 'http' then
      ngx.log(ngx.INFO, 'Location: ' .. location)
      location = exResolve( target , location )
    end
    ngx.log(ngx.INFO, "Resolved Location " .. location)
  end
  return location
 end

function resHeaders( target, res )
  local httpc = http.new()
  local scheme, host, port, path = unpack(httpc:parse_uri(target))
  local base = scheme .. '://' .. host
  local linkURL = nil
  local linkHeader = getLinkHeaderURL( res )
  if linkHeader ~= nil then
    ngx.log(ngx.INFO, ' - got a valid rel mention item : [ ' .. linkHeader  .. ' ]' )
    ngx.log(ngx.INFO, ' - try to get link ... ' )
    linkURL = getLinkURL(linkHeader)
    if linkURL ~= nil then
      ngx.log(ngx.INFO, '- got link URL: [ ' .. linkURL .. ' ]' )
      ngx.log(ngx.INFO, '- try to resolve URI ... ')
      if string.sub( linkURL, 1, 1 ) == '/' then
        linkURL = base .. linkURL
      end
      if string.sub( linkURL, 1, 4 ) ~= 'http' then
        linkURL = exResolve( target , linkURL )
      end
    end
  end
  if linkURL ~= nil then
    ngx.log( ngx.INFO, 'Resolved: ' .. linkURL )
  end
  return linkURL
end

function resBody( target, res )
  local linkURL = nil
  if res.has_body then
    local httpc = http.new()
    local scheme, host, port, path = unpack(httpc:parse_uri(target))
    local base = scheme .. '://' .. host
    body, err = res:read_body()
    local exResult = exQuery(body)
    if exResult ~= nil then
      ngx.log(ngx.INFO, 'link URL: ' .. exResult)
      if exResult == 'thePageIsOwnEndpoint' then
        linkURL = target
      elseif string.sub( exResult, 1, 1 ) == '/' then
        linkURL = base .. exResult
      elseif string.sub( exResult, 1, 4 ) ~= 'http' then
        linkURL = exResolve( target , linkURL )
      else
        linkURL = exResult
      end
    end
  end
  return linkURL
end

 function getLinkHeaderURL( response )
   ngx.log(ngx.INFO, "LOOK for rel webmention Link in resonse headers")
   local headerLink = response.headers['Link']
   local linkItem = nil
   ngx.log(ngx.INFO, " - found Link type ..." .. type(headerLink) )
   if type(headerLink) == 'string' then
     -- might be multiple link headers ... look for comma seperator
     local links , err = require('ngx.re').split(headerLink, ",")
     if type(links) == 'table' then
       for index, item in ipairs ( links ) do
         ngx.log(ngx.INFO, ' - found link '  .. tostring(index) .. ' [ ' .. item .. ' ]' )
         linkItem =  getLinkItem( item )
         if linkItem ~= nil then
           break
         end
       end
     end
   end
   if type(headerLink) == 'table' then
     for index, item in ipairs (headerLink) do
       linkItem =  getLinkItem( item )
       if linkItem ~= nil then
         break
       end
     end
   end
   return linkItem
 end

 function getLinkItem( item )
   ngx.log(ngx.INFO, "LOOK for 'rel=mention' : [ " .. item  .. ' ]' )
   local relMentionString = nil
   local from, to, err = ngx.re.find(item ,'(rel=webmention|rel="webmention"|rel="webmention.+")')
   if from then
     local linkRel =  string.sub( item, from, to )
     ngx.log(ngx.INFO, ' - OK webmention found: ' .. linkRel )
     relMentionString = item
   end
   return relMentionString
 end

 function getLinkURL( strLink )
   local from, to, err = ngx.re.find( strLink,"<(.+)>" )
   if from then
     from = from +1
     to = to -1
     return string.sub( strLink, from, to )
   else
     if err then
       ngx.log(ngx.INFO, "error: ", err)
     end
     ngx.log(ngx.INFO, "not matched!")
   end
   return nil
 end

function exQuery( body )
  local binary = ngx.encode_base64( body )
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $binary := "]] .. binary.. [["
    let $doc := util:parse-html(util:base64-decode($binary))
    return
     if ( $doc/html/head/link[@rel='webmention']/@href ) then
       if ($doc/html/head/link[@rel='webmention']/@href/string() eq '' ) then
        'thePageIsOwnEndpoint'
       else
       $doc/html/head/link[@rel='webmention']/@href
     else if ( $doc/html/head/link[matches(@rel/string(), '^webmention|\swebmention$|\swebmention\s')]/@href ) then
       $doc/html/head/link[contains(@rel/string(),'webmention')]/@href
     else if ( $doc/html/body//*[self::a or self::link][@rel='webmention'] ) then
     if ( $doc/html/body//*[self::a or self::link][@rel='webmention']/@href/string() eq '' ) then
        'thePageIsOwnEndpoint'
       else
        $doc/html/body//*[self::a or self::link][@rel='webmention']/@href/string()
     else ()
     ]] ..']]>' .. [[
    </text>
  </query>
]]
  local responseBody =  require('grantmacken.eXist').restQuery( txt )
  if responseBody == '' then
    responseBody = nil
  end
    return responseBody
end

function exResolve( base , pth )
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace muURL="http://markup.nz/#muURL"
      at "xmldb:exist:///db/apps/]] .. cfg.get('domain')  .. [[/modules/lib/muURL.xqm";
    let $base := "]] .. base .. [["
    let $relPath := "]] .. pth.. [["
    return muURL:resolve( $base, $relPath )
     ]] ..']]>' .. [[
    </text>
  </query>]]
  local responseBody =  require('grantmacken.eXist').restQuery( txt )
  if responseBody == '' then
    responseBody = nil
  end
  return responseBody
end



return _M
