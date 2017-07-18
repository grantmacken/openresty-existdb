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


function _M.syndicateToTwitter( jData )
  ngx.log(ngx.INFO, ' Syndicate To Twitter ' )
  ngx.log(ngx.INFO, '----------------------' )
  -- local method = 'GET'
  local method = 'POST'
  -- local request = 'https://api.twitter.com/1.1/statuses/user_timeline.json'
  local queryTbl = { 
    status = 'hi de hi'

  }
  local request = 'https://api.twitter.com/1.1/statuses/update.json'
  -- local queryTbl = { 
  --   count = '1',
  --   exclude_replies = 'false'
  -- }
 --  local request = 'https://api.twitter.com/1.1/statuses/update.json'
  -- local method = 'POST'
  local httpc = require('resty.http').new()
  -- local request = 'https://api.twitter.com/1.1/statuses/update.json'
  -- ?status=Maybe%20he%27ll%20finally%20find%20his%20keys
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

  ngx.log(ngx.INFO, ' - method: ' .. method )
  ngx.log(ngx.INFO, ' - resource: ' .. resource )

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



  --local authHeader = getTwitterAuthorizationHeader( tbl )
  local response = nil
  local err = nil
    ngx.log(ngx.INFO, ' GET  twitter resource' )
    ngx.log(ngx.INFO, '----------------------' )
   -- local authHeader = getTwitterAuthorizationHeader( tbl )
    httpc:set_timeout(6000)
    response, err = httpc:request({
        ['method'] = tbl.method,
        ['path'] = path,
        ['headers'] = {
          ["Authorization"] =  makeTwitterRequest( tbl, queryTbl ),
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


function makeTwitterRequest( tbl , qTbl )
  ngx.log(ngx.INFO, ' Make Twitter Request ' )
  ngx.log(ngx.INFO, '----------------------------------' )
  local domain  = ngx.var.domain
  ngx.log( ngx.INFO,  domain )

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
        oAuth:makeRequest( $map, $qMap   )
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

function makeTwitterPostRequest( tbl )
  ngx.log(ngx.INFO, ' Make Twitter Request ' )
  ngx.log(ngx.INFO, '----------------------------------' )
  local domain  = ngx.var.domain
  ngx.log( ngx.INFO,  domain )

  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace oAuth="http://markup.nz/#oAuth" at "xmldb:exist:///db/apps/]] .. domain  .. [[/modules/lib/oAuth.xqm";
    try {
    let $map := map ]] .. cjson.encode( tbl ) .. [[
      return (
        oAuth:makePostRequest( $map )
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

function getTwitterAuthorizationHeader( tbl )
  ngx.log(ngx.INFO, ' Get Twitter Authorization Header ' )
  ngx.log(ngx.INFO, '----------------------------------' )
  local domain  = ngx.var.domain
  ngx.log( ngx.INFO,  domain )

  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace util = "http://exist-db.org/xquery/util";
    import module namespace oAuth="http://markup.nz/#oAuth" at "xmldb:exist:///db/apps/]] .. domain  .. [[/modules/lib/oAuth.xqm";
    try {
    let $timeStamp := oAuth:createTimeStamp()
    let $nonce := oAuth:createNonce()
    let $map := map ]] .. cjson.encode( tbl ) .. [[
    let $status := xmldb:decode-uri($map('status'))
    let $params := map {
      'status' : $status,
      'oauth_consumer_key' :  $map('oauth_consumer_key'),
      'oauth_nonce' : $nonce,
      'oauth_signature_method' : 'HMAC-SHA1',
      'oauth_timestamp' : $timeStamp,
      'oauth_token' : $map('oauth_token'),
      'oauth_version' : '1.0'
      }

    let $resource := xmldb:decode-uri($map('resource')) 
    let $log1 := util:log-system-out( 'timestamp: ' || $params('oauth_timestamp'))
    let $log2 := util:log-system-out('nonce: '  || $params('oauth_nonce') )
    let $log3 := util:log-system-out('resource: '  || xmldb:decode-uri($map('resource')) )
    let $log4 := util:log-system-out('status: '  || xmldb:decode-uri($map('status')) )

    let $oAuthSignature :=
       oAuth:calculateSignature(
        oAuth:createSignatureBaseString(
          $map('method'),
          $resource,
          oAuth:createParameterString( $params )
        ),
        oAuth:createSigningKey(
        $map('oauth_consumer_secret'),
        $map('oauth_token_secret'))
      )

     let $headerMap :=
        map {
          'oauth_consumer_key' : $map('oauth_consumer_key'),
          'oauth_nonce' :  $params('oauth_nonce'),
          'oauth_signature' : $oAuthSignature ,
          'oauth_signature_method' : $params('oauth_signature_method'),
          'oauth_timestamp' : $params('oauth_timestamp'),
          'oauth_token' : $map('oauth_token'),
          'oauth_version' : $params('oauth_version')
          }

      return (
        oAuth:buildHeaderString( $headerMap )
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

function getTwitterAuthorizationHeader2( tbl )
  ngx.log(ngx.INFO, ' Get Twitter Authorization Header ' )
  ngx.log(ngx.INFO, '----------------------------------' )
  local domain  = ngx.var.domain
  ngx.log( ngx.INFO,  domain )

  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace util = "http://exist-db.org/xquery/util";
    import module namespace oAuth="http://markup.nz/#oAuth" at "xmldb:exist:///db/apps/]] .. domain  .. [[/modules/lib/oAuth.xqm";
    try {
    let $timeStamp := oAuth:createTimeStamp()
    let $nonce := oAuth:createNonce()
    let $map := map ]] .. cjson.encode( tbl ) .. [[
    let $params := map {
      'oauth_consumer_key' :  $map('oauth_consumer_key'),
      'oauth_nonce' : $nonce,
      'oauth_signature_method' : 'HMAC-SHA1',
      'oauth_timestamp' : $timeStamp,
      'oauth_token' : $map('oauth_token'),
      'oauth_version' : '1.0'
      }

    let $resource := xmldb:decode-uri($map('resource')) 
    let $log1 := util:log-system-out( 'timestamp: ' || $params('oauth_timestamp'))
    let $log2 := util:log-system-out('nonce: '  || $params('oauth_nonce') )
    let $log3 := util:log-system-out('resource: '  || xmldb:decode-uri($map('resource')) )

    let $oAuthSignature :=
       oAuth:calculateSignature(
        oAuth:createSignatureBaseString(
          $map('method'),
          $resource,
          oAuth:createParameterString( $params )
        ),
        oAuth:createSigningKey(
        $map('oauth_consumer_secret'),
        $map('oauth_token_secret'))
      )

     let $headerMap :=
        map {
          'oauth_consumer_key' : $map('oauth_consumer_key'),
          'oauth_nonce' :  $params('oauth_nonce'),
          'oauth_signature' : $oAuthSignature ,
          'oauth_signature_method' : $params('oauth_signature_method'),
          'oauth_timestamp' : $params('oauth_timestamp'),
          'oauth_token' : $map('oauth_token'),
          'oauth_version' : $params('oauth_version')
          }

      return (
        oAuth:buildHeaderString( $headerMap )
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




  -- httpc:set_timeout(3000) -- 6 sec timeout
  -- local ok, err = httpc:connect(host, port)
  -- if not ok then
  --   msg = "FAILED to connect to " .. host .. " on port "  .. port .. ' - ERR: ' ..  err
  --   return {}, msg
  -- else
  --   ngx.log(
  --     ngx.INFO,
  --     " - connected to " .. host .. " on port "  .. port )
  -- end

  -- -- 4 sslhandshake opts
  -- local reusedSession = nil   -- defaults to nil
  -- local serverName = host     -- for SNI name resolution
  -- local sslVerify = false     -- boolean if true make sure the directives set
  -- -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth 
  -- local sendStatusReq = '' -- boolean OCSP status request
  -- local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
  -- if not shake then
  --   ngx.log(
  --     ngx.INFO,
  --     'FAILED SSL handshake with  '  .. serverName ..  ' on port '  .. port )
  --   return {}, msg
  -- else
  --   ngx.log(
  --     ngx.INFO,
  --     " - SSL Handshake Completed: "  .. type(shake))
  -- end


  -- if ( method == 'GET' ) then
  --   ngx.log( ngx.INFO, " - method " .. method )
  --   ngx.log( ngx.INFO, " - path " .. path )
  --   --ngx.log( ngx.INFO, " - Authorization " .. authHeader )
  --   httpc:set_timeout(6000)
  --   local response, err = httpc:request({
  --       ['method'] = method,
  --       ['path'] = path,
  --       ['headers'] = {
  --         ["Authorization"] = authHeader,
  --       }
  --     }
  --     )
  --   if not response then
  --     msg = "failed to complete request: ", err
  --     ngx.log( ngx.INFO, msg )
  --     return {}, msg
  --   end
  --   if response.has_body then
  --     body, err = response:read_body()
  --     if not body then
  --       msg = "twitter failed to return reponse body"
  --       return {}, msg
  --     end
  --     ngx.log( ngx.INFO, body )
  --   end
  -- end

  -- if ( method == 'POST' ) then
  --   ngx.log( ngx.INFO, " - method " .. method )
  --   ngx.log( ngx.INFO, " - path " .. path )
  --   --ngx.log( ngx.INFO, " - Authorization " .. authHeader )
  --   httpc:set_timeout(6000)
  --   local response, err = httpc:request({
  --       ['method'] = method,
  --       ['path'] = path,
  --       ['headers'] = {
  --         ["Content-Type"] = "application/x-www-form-urlencoded",
  --         ["Authorization"] = authHeader,
  --         ["query"] = {
  --           status = 'hi di hi'
  --         }
  --       }
  --     })
  --   if not response then
  --     msg = "failed to complete request: ", err
  --     ngx.log( ngx.INFO, msg )
  --     return {}, msg
  --   end
  --   if response.has_body then
  --     body, err = response:read_body()
  --     if not body then
  --       msg = "twitter failed to return reponse body"
  --       return {}, msg
  --     end
  --     ngx.log( ngx.INFO, body )
  --   end
  -- end



  -- ngx.log(ngx.INFO, '----Syndicated--------' )

return _M
