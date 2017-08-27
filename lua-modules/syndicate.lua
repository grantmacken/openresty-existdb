local _M = {}
--[[
--https://dev.twitter.com/oauth/overview/creating-signatures
--https://dev.twitter.com/oauth/overview/authorizing-requests
--https://dev.twitter.com/rest/reference/get/account/settings
--GET https://api.twitter.com/1.1/account/settings.json
--https://api.twitter.com/1.1/statuses/update.json?include_entities=true
--]]

local twtTable = cjson.decode( ngx.var[ 'twitterAuth' ] )

local function get( item )
  return twtTable[item]
end

--[[

notes:  oAuth with twitter

- twitterAuth holds twitter 'key', 'value' credentials in json format
and are in an env var

- pass 3 params to functions

local method = 'GET'
local request = 'https://api.twitter.com/1.1/statuses/user_timeline.json'
local queryTbl = { 
    count = '1',
    exclude_replies = 'false'
  }
the query table are the url query params that you can look up url-query-params
in the ref docs
@see https://dev.twitter.com/rest/reference

--]]



function _M.syndicateToTwitter( note )
  ngx.log(ngx.INFO, ' Syndicate To Twitter ' )
  ngx.log(ngx.INFO, '----------------------' )
  local request = 'https://api.twitter.com/1.1/statuses/update.json'
  ngx.log(ngx.INFO, ' - status: ' ..  note)
  ngx.log(ngx.INFO, ' - request: ' .. request)
  local method = 'POST'
  local queryTbl = { 
     ['status'] = note
   }
  twitterRequest( method, request, queryTbl )
end

function twitterRequest( method, request, queryTbl )
  ngx.log(ngx.INFO, '  Twitter API Request ' )
  ngx.log(ngx.INFO, '----------------------' )
  local httpc = require('resty.http').new()
  local scheme, host, port, path = unpack(httpc:parse_uri( request ))
  local resource = scheme .. '://' .. host .. path
  local tbl = {
    ['method']  =  method,
    ['resource'] =  ngx.escape_uri( scheme .. '://' .. host .. path ),
    ['oauth_consumer_key'] =  get( 'oauth_consumer_key' ),
    ['oauth_consumer_secret'] =   get( 'oauth_consumer_secret' ),
    ['oauth_token'] =  get( 'oauth_token' ),
    ['oauth_token_secret'] =  get( 'oauth_token_secret' )
  }

  httpc:set_timeout(6000) -- 6 sec timeout
  ngx.log(
      ngx.INFO,
      " - connecting to " .. host .. " on port "  .. port )
  local ok, err = httpc:connect(host, port)
  if not ok then
    msg = "FAILED to connect to " .. host .. " on port "  .. port .. ' - ERR: ' ..  err
    return {}, msg
  else
    ngx.log(
      ngx.INFO,
      " - connected to " .. host .. " on port "  .. port )
  end
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

  local response = nil
  local err = nil
    ngx.log(ngx.INFO, ' GET  twitter resource' )
    ngx.log(ngx.INFO, '----------------------' )
    httpc:set_timeout(6000)
    response, err = httpc:request({
        ['method'] = tbl.method,
        ['path'] = path,
        ['headers'] = {
          ["Authorization"] =  getTwitterAuthorizationHeader( tbl, queryTbl ),
        },
        ['query'] =  queryTbl
      }
      )

  if not response then
    msg = "failed to complete request: ", err
    ngx.log( ngx.INFO, msg )
    return {}, msg
  end
  if response.has_body then
    body, err = response:read_body()
    if not body then
      msg = "twitter failed to return reponse body"
      return {}, msg
    end
    ngx.log( ngx.INFO, body )
  end
end

function getTwitterAuthorizationHeader( tbl , qTbl )
  ngx.log(ngx.INFO, ' Twitter Authorization Header' )
  ngx.log(ngx.INFO, '------------------------------' )
  local domain  = ngx.var.domain
  -- ngx.log( ngx.INFO,  domain )
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace oAuth="http://markup.nz/#oAuth" at "xmldb:exist:///db/apps/]] .. domain  .. [[/modules/lib/oAuth.xqm";
    try {
    let $map := map ]] .. cjson.encode( tbl ) .. [[
    let $qMap := map ]] .. cjson.encode( qTbl ) .. [[
      return (
        oAuth:authorizationHeader( $map, $qMap   )
      )
    }
    catch *{()}
     ]] ..']]>' .. [[
    </text>
  </query>
]]
  local responseBody =  require('grantmacken.eXist').restQuery( txt )
  ngx.log(ngx.INFO, "body: ", responseBody)
  ngx.log(ngx.INFO, '----------------------------------' )
  return responseBody
end

return _M
