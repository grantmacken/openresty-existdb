local _M = {}

--[[

delegation of endpoints for authentication


#
 - [authorization-endpoint]( https://indieweb.org/authorization-endpoint )
   identify user OR obtain athorization code 
 use an existing authorization service such as indieauth.com
 
# VERIFICATION
 [token-endpoint] (https://indieweb.org/token-endpoint)
  grant an access token as well as verify an access token

 is token valid?

  make a request to the token endpoint to verify that an incoming access token is valid
 server - `verifyAccessToken`
 https://tokens.indieauth.com/

  returns
  Content-Type: application/x-www-form-urlencoded

  inspect these values and determine whether to proceed with the request
  `
 1. client creates post and send to micropub endpoint 
 2. sent token will be in the Authorization header or in the post args

 - extractToken
 - verifyToken


lua modules used

@see https://github.com/pintsized/lua-resty-http
@see http://doc.lubyk.org/xml.html

 https://github.com/openresty/lua-nginx-module#tcpsocksslhandshake
 https://github.com/openresty/lua-nginx-module#ssl_certificate_by_lua_block
 https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#readme
 https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ocsp.md#readme
 http://lua-users.org/lists/lua-l/2016-01/msg00129.html
 https://github.com/aptise/peter_sslers

@see  https://indieweb.org/token-endpoint
@see  https://www.w3.org/TR/micropub/
 
 - MUST support both header and form parameter methods of authentication
 - MUST support creating posts with the [h-entry] vocabulary

TEST: curl

1. token in the HTTP Authorization header

 curl -H "authorization: Bearer $(<../.me-access-token)" https://gmack.nz/token

2. token in the post body for x-www-form-urlencoded requests

curl -L  https://gmack.nz/_token -d "access_token=$(<../.me-access-token)"

3. POST   x-www-form-urlencoded 

 curl -H "authorization: Bearer $(<../.me-access-token)" https://gmack.nz/micropub  -d 'h=entry' -d 'content=hello world'
 4. POST application/json

 curl -H "Content-Type: application/json"  -H "authorization: Bearer $(<../.me-access-token)" https://gmack.nz/micropub -d '{"type": ["h-entry"],"properties":{"content": ["hello world"]}}'


 id unique to the db
   [a-z]{1}  shortKindOfPost n = note
   O
   [\w]{3}   short date base60 encoded 
   [\w]{1}   the base60 encoded incremented number of entries for the day
   total of 5 chars 
  the short URL http://{domain}/{uid)  - no extension
  expanded  URL http://{domain}/{YEAR}/{MONTH}/{DAY}/{KIND}/{CHAR}
  where kind = kind of post e.g. note
  where char = the incremented entry number for the day
  5 chars limited to less than 60 entries for the day
  6 chars  limited to less than 360 entries for the day

  URL http://{domain}/{YEAR}/{MONTH}/{DAY}/notes
  list notes for day

  URL http://{domain}/{YEAR}/{MONTH}/{DAY}
  list any archived posts for day

  URL http://{domain}/{YEAR}/{MONTH}
  list archived posts for month 

  URL http://{domain}/{YEAR}/{MONTH}/notes
  list notes for month
  
  etc

--]]

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

function contains(tab, val)
  for index, value in ipairs (tab) do
    if value == val then
      return true
    end
  end

  return false
end

function Set (list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

--[[
3.8 Error Response
https://www.w3.org/TR/micropub/#error-response
--]]

local function requestError( status, msg ,description)
  ngx.status = status
  ngx.header.content_type = 'application/json'
  local json = cjson.encode({
      error  = msg,
      error_description = description
    })
  ngx.print(json)
  ngx.exit(status)
end

function extractToken()
  --TODO! token in post args
  --access_token - the OAuth Bearer token authenticating the request
  --(the access token may be sent in an HTTP Authorization header or
  --this form parameter)
  local token  = ngx.var.http_authorization
  if token  ~=  nil then
     token  = token:split(' ')[2]
     return token
   end

  ngx.req.read_body()
  local token  = ngx.req.get_post_args()['access_token']
  if token  ~=  nil then
    return token 
  end

 return  requestError(ngx.HTTP_UNAUTHORIZED,'invalid_request', 'no access token sent') 
end

function _M.verifyToken()
  local ssl = require "ngx.ssl"
  local jwt = require "resty.jwt"
  local url = require "net.url"
  local jwtObj = jwt:load_jwt(extractToken())

  if not jwtObj.valid then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'not a jwt token') 
  end

  local me = jwtObj.payload.me
  if me == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing me') 
  end

  local clientID = jwtObj.payload.client_id
  if clientID == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing client id') 
  end

  local scope = jwtObj.payload.scope
  if scope == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing scope') 
  end

  local issuedAt = jwtObj.payload.issued_at
  if  issuedAt == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing issued_at') 
  end

  local issuedBy = jwtObj.payload.issued_by
  if  issuedBy == nil then
   return  requestError(ngx.HTTP_BAD_REQUEST,'invalid_token', 'missing issued by') 
  end

  -- local json = cjson.encode(jwtObj.payload)
  -- ngx.say(json)

-- am I the one who authorized the use of this token
-- TODO! establish my sni name

  local serverName = ssl.server_name()
  if serverName == nil then
   return  requestError(ngx.HTTP_FORBIDDEN,'insufficient_scope', 'can not establish serrver name') 
  end

  local domain = url.parse(me).host

   --  ngx.say(domain)
  if serverName ~= domain  then
   return  requestError(ngx.HTTP_FORBIDDEN,'insufficient_scope', 'you are not me') 
  end

-- I have the appropiate post scope
  if scope ~= 'post'  then
   return  requestError(ngx.HTTP_FORBIDDEN,'insufficient_scope', ' do not have the appropiate post scope') 
  end

-- I have the appropiate post scope
-- TODO! scope is a list
--  ngx.say(clientID)

-- I accept posts only from the following clients
-- TODO!
--
-- I accept tokens no older than 
-- -- TODO!

 return 'token verifed'

-- return ngx.encode_args(jwtObj.payload)
-- return cjson.encode(jwtObj.payload)

  -- ngx.status =  ngx.status = ngx.HTTP_OK
  -- ngx.header.content_type = 'application/json'
  -- local json = cjson.encode(jwtObj.payload)
  -- ngx.say(json)
  -- ngx.exit(ngx.HTTP_OK)
end


function encodeDate()
  local shortDate = os.date("%y") .. os.date("*t").yday
  local integer = tonumber(shortDate )
  return b60Encode(integer)
end

function b60Encode(remaining)
  local chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ_abcdefghijkmnopqrstuvwxyz'
  local slug = ''
  --local remaining = tonumber(str)
  while (remaining > 0) do
    local d = (remaining % 60)
    local character = string.sub(chars, d + 1, d + 1)
    slug = character .. slug
    remaining = (remaining - d) / 60
  end
return slug
end

function discoverPostType(props)
  -- https://www.w3.org/TR/post-type-discovery/
  -- p['rsvp'] = true
  -- p['in-reply-to'] = true
  -- p['repost-of'] = true
  -- p['like-of'] = true
  -- p['video'] = true
  -- p['photo'] = true
  local kindOfPost = nil
  for key, val in pairs(props) do
    if key == "rsvp" then
      --TODO check valid value
      kindOfPost = 'RSVP'
      return kindOfPost
    elseif key == "in-reply-to" then
      --TODO check valid value
      kindOfPost = 'reply'
      return kindOfPost
    elseif key == "repost-of" then
      --TODO check valid value
      kindOfPost = 'share'
      return kindOfPost
    elseif key == "like-of" then
      --TODO check valid value
      kindOfPost = 'like'
      return kindOfPost
    elseif key == "video" then
      --TODO check valid value
      kindOfPost = 'video'
      return kindOfPost
    elseif key == "photo" then
      --TODO check valid value
      kindOfPost = 'photo'
      return kindOfPost
    elseif key == "name" then
      --TODO check valid value
      kindOfPost = 'article'
      return kindOfPost
    else
      kindOfPost = 'note'
      return kindOfPost
    end
  end
  
  -- if  == 'rsvp' then
  --  return 'RSVP'
  -- end
 return kindOfPost
end


function getID(k)
  local slugDict = ngx.shared.slugDict
  local count = slugDict:get("count") or 0
  -- setup count and today
  if count  == 0 then
    slugDict:add("count", count)
    slugDict:add("today", encodeDate())
  end
 -- if the same day increment
 -- otherwise reset today and reset counter
  if slugDict:get("today") == encodeDate() then
    -- ngx.say('increment counter')
    slugDict:incr("count",1)
    --ngx.say(slugDict:get("count"))
    --ngx.say(slugDict:get("today"))
  else
    -- ngx.say('reset counter')
   slugDict:replace("today", encodeDate())
   slugDict:replace("count", 1)
 end
  --slugDict:replace("count", 1)
-- ngx.say(slugDict:get("count"))
-- ngx.say(slugDict:get("today"))
 return k .. slugDict:get("today") .. b60Encode(slugDict:get("count"))
end

function redisStore(tbl)
  -- https://github.com/openresty/lua-resty-redis
  -- http://redis.io/commands
   -- slugDict:replace("count", 1)

  local redis = require "resty.redis"
  local red = redis:new()

  red:set_timeout(1000) -- 1 sec

  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
    ngx.say("failed to connect: ", err)
    return
  end

    --ngx.say(slugDict:get("count"))
    --ngx.say(slugDict:get("today"))
    json = cjson.encode(tbl['type'])
    ngx.say(json)

   local hash = slugDict:get("today") .. slugDict:get("count")
   ngx.say ( hash )


    local res, err = red:hmset (hash,'type', tbl['type'])
    if not res then
      ngx.say("failed: ", err)
      return
    end

    local res, err = red:hmset (hash,tbl['properties'])
    if not res then
      ngx.say("failed: ", err)
      return
    end

    -- local res, err = red:hmget(hash, type)
    -- if not res then
    --   ngx.say("failed: ", err)
    --   return
    -- end


    --    ngx.say(type(res))


   ngx.say("res: ", cjson.encode(res))

    local res, err = red:hget(hash, 'published' )
    if not res then
      ngx.say("failed: ", err)
      return
    end
    ngx.say("res: ",type(res))
    ngx.say("res: ", cjson.encode(res))

    local res, err = red:hgetall(hash)
    if not res then
      ngx.say("failed: ", err)
      return
    end
    ngx.say("res: ",type(res))
    ngx.say("res: ", cjson.encode(res))
end



function processFormArgs()
  local data = {} -- the xml based table to return
  local msg = ''
  ngx.req.read_body()
  local args, err = ngx.req.get_post_args()
  if not args then
    ngx.say("failed to get post args: ", err)
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      'failed to get post args')
  end
  
-- Post Objects
-- https://www.w3.org/TR/jf2/#post-objects
-- http://microformats.org/wiki/microformats-2#v2_vocabularies
  
  local hType = args.h
  --ngx.say(hType)
  if hType == nil then
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      'no type of post defined')
  end
  --  TODO if no type is specified, the default type [h-entry] SHOULD be used.

  local hTypes = {}
  hTypes['entry'] = true
  hTypes['card'] = false
  hTypes['event'] = false
  hTypes['cite'] = false

  msg = 'can not handle microformat "Post Object type": ' .. hType
  if not hTypes[hType] then
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg )
  end



  -- Post Properties
  -- https://www.w3.org/TR/jf2/#post-properties

  local properties = {}
  -- TODO expand entry properties and place in data module
  p = {}
  p['name'] = true
  p['summary'] = true
  p['rsvp'] = true
  p['in-reply-to'] = true
  p['repost-of'] = true
  p['like-of'] = true
  p['video'] = true
  p['photo'] = true
  p['content'] = true
  p['published'] = false
  p['updated'] = false

  for key, val in pairs(args) do
    if type(val) == "table" then
      ngx.say(type(val))
      ngx.say(key, ": ", table.concat(val, ", "))
    else    
      -- ngx.say(type(val))
      -- ngx.say(key, ": ", val)
      if p[key] ~=  nil then
        properties[key] = val
      end
    end
  end

  -- ' we have a the properties of an entry'
  -- 'discovery the post type' 
  local kindOfPost = discoverPostType( properties )
   -- top level entry
   data = { 
     xml = hType, 
     type = kindOfPost
   } 

 -- ngx.say(kindOfPost)
 -- getID()
 -- ngx.say('--------------------------------------------------------')

  properties['published'] = getToday()
 --  properties['id'] = 'tag:' .. host .. ',' ..  getToday() .. ':' .. kindOfPost .. ':'  ..  getID()

  properties['id'] =  getID(require('mydata').getShortKindOfPost(kindOfPost))
  for key, val in pairs(properties) do
    -- ngx.say(type(val))
    -- ngx.say(key, ": ", val)
    table.insert(data,1,{ xml = key, val })
  end
 return data
end

function acceptMethods(methods)
  --  the methods this endpoint can handle
  local method = ngx.req.get_method()
  if not contains( methods, method )  then
    return requestError(
      ngx.HTTP_METHOD_NOT_IMPLEMENTED,
      method .. ' method not implemented',
      'endpoint only implements POST and GET methods') 
  end
 return method  
end

function acceptContentTypes(contentTypes)
  --  the content-types this endpoint can handle
  local contentType = ngx.req.get_headers()["Content-Type"]
  if not contains(contentTypes,contentType)  then
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      'endpoint only accepts json or x-www-form-urlencoded content-type')
  end
  return contentType
end

function _M.validateRequestParameters()
  local host = ngx.req.get_headers()["Host"]
  --  the methods this endpoint can handle
  local method =  acceptMethods({"POST","GET"})
  -- ngx.say( method )
  -- the content-types this endpoint can handle
  local contentType = acceptContentTypes({'application/json','application/x-www-form-urlencoded'})
  -- ngx.say( contentType )
  -- MUST support creating posts using the x-www-form-urlencoded syntax

  -- MUST support creating posts with the [h-entry] vocabulary
  --  the microformat objects this endpoint can handle at the mo
  local data = {}
  ngx.req.read_body()
  if contentType  == 'application/x-www-form-urlencoded' then
    -- ngx.say(contentType)
     data  = processFormArgs()
  elseif contentType  == 'application/json' then
   -- postData = cjson.decode(ngx.req.get_body_data())
   --  hType = postData['type']
 end

 require('eXist').putXML(data)

 -- local xml = require 'xml'
  -- local lub = require 'lub'
  -- ngx.say(require('xml').dump(data))

   -- local resource = xml.find(data, 'id')[1]
   -- ngx.say(resource)
   --local  = xml.find(data, 'type' )
-- local x = lub.join({'foo', 'bar', 'baz'}, '.')
   -- ngx.say(type(data))
   -- local kind = xml.find(data,'entry')['type'] 
   -- ngx.say(kind)
   --  ngx.say(require('mydata').getShortKindOfPost(kind))

  -- note data is a lua table 
  -- could send xml as param instead 
  -- on success return
  -- https://www.w3.org/TR/micropub/#response
end

return _M
