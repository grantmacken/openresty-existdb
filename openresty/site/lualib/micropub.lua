local _M = {}

--[[

lua modules used

@see https://github.com/openresty/lua-nginx-module

@see https://github.com/pintsized/lua-resty-http
@see http://doc.lubyk.org/xml.html

luarocks install lua-resty-http
luarocks install xml

@see  https://indieweb.org/token-endpoint
@see  https://www.w3.org/TR/micropub/
 
 - MUST support creating posts with the [h-entry] vocabulary

TEST: curl

1. a x-www-form-urlencoded POST request : emulate a HTML formx-www-form-urlencoded 

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


-- https://www.w3.org/TR/micropub/#h-reserved-properties
-- note reserved extension mp-* 

local reservedPostPropertyNames = {
  access_token = true,
  h = true,
  q = true,
  action = true,
  url = true
}


 -- https://www.w3.org/TR/micropub/#create
 --  handle these microformat Object Types
 --  TODO!  mark true when can handle
 --
local microformatObjectTypes = {
  entry = true,
  card = false,
  event = false,
  cite = false
}

local actionTypes = {
   update = true,
   delete = true,
   undelete = true
   }

local updateTypes = {
    add = true,
    delete = true,
    replace = true
   }

local shortKindOfPost = {
 note = 'n'
}

function getShortKindOfPost(kind)
  return shortKindOfPost[kind]
end

function contains(tab, val)
  for index, value in ipairs (tab) do
    if value == val then
      return true
    end
  end
  return false
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

function getToday()
  return os.date("%Y-%m-%d")
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


function processPostArgs()
  -- ngx.say(' process POST arguments ' )
  local msg = ''
  ngx.req.read_body()
  local args, err = ngx.req.get_post_args()
  if not args then
    msg = "failed to get post args: " ..  err
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
  if args['h'] then
    -- ngx.say( ' assume we are creating a post item'  )
    local hType = args['h']
    if not microformatObjectTypes[hType] then
      msg = 'can not handle microformat  object type": ' .. hType
      return requestError(
        ngx.HTTP_NOT_ACCEPTABLE,
        'not accepted',
        msg )
    end

  --  TODO if no type is specified, the default type [h-entry] SHOULD be used.

    if hType == 'entry' then
     local data = createEntry(args)
     -- ngx.say(require('xml').dump(data))
     -- ngx.say(' store XML data into eXistdb ' )
     require('eXist').putXML(data)
    end
  elseif args['action'] then
    ngx.say( ' assume we are modifying a post item in some way'  )
    ngx.say ('TODO!')
  else
    msg = "failed to get actionble POST argument, h or action required"
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
end

function createEntry(args)
  local hType = args['h']
  -- ngx.say( 'create ' .. hType  ..  ' entry item with args' )
  local data = {} -- the xml based table to return
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
       --  ngx.say(type(val))
       -- ngx.say(key, ": ", val)
      if p[key] ~=  nil then
        properties[key] = val
      end
    end
  end

  -- ' we have sent properties of an entry ' 
  -- ' now add server generated properties '
  -- ' from the sent properties - discovery the kind of post '
   local kindOfPost = discoverPostType( properties )

    -- ngx.say( ' add ' .. kindOfPost .. ' as an "type" attribute to documentElement: ' .. hType )

   -- top level entry
   data = { 
     xml = hType, 
     type = kindOfPost
   } 

   properties['published'] = getToday()
   -- ngx.say( 'add published property: '  .. properties['published'] )
   properties['id'] =  getID(getShortKindOfPost(kindOfPost))
   -- ngx.say( 'add id property: '  .. properties['id'] )
   -- ngx.say( 'now create the table that can be converted to XML' )
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

function processPost()
   -- ngx.say('the content-types this endpoint can handle')
   local contentType = acceptContentTypes({'application/json','application/x-www-form-urlencoded'})
   -- ngx.say( contentType )
     if contentType  == 'application/x-www-form-urlencoded' then
      processPostArgs()
  elseif contentType  == 'application/json' then
    
    ngx.say( contentType )
    ngx.req.read_body()
    local args  = cjson.decode(ngx.req.get_body_data())

    local acceptKey = {
      action = true
    }

    for key, val in pairs(args) do
      if type(val) == "table" then
        ngx.say(type(val))
        ngx.say(key, ": ", table.concat(val, ", "))
      else    
        ngx.say(type(val))
        ngx.say(key, ": ", val)
      end
    end
    if args['action'] then 
      --[[
    To update an entry, send "action": "update" and specify the URL of the entry that is being updated using the "url" property. The request MUST also include a replace, add or delete property (or any combination of these) containing the updates to make.
    --]]

      local action = args['action']
      if action == 'update' then
        ngx.say(action)
        local url = args['url']
        if url == nil then
          ngx.say("exit TODO")
        end

        -- do any combination
        if args['replace'] then
          ngx.say("do replace")
          -- args.replace should be table
          ngx.say(type(args['replace']))
          local replaceItems = args['replace']

          for key, val in pairs(replaceItems) do
            if type(val) == "table" then
              ngx.say(type(val))
              ngx.say(key, ": ", table.concat(val, ", "))
            else    
              ngx.say(type(val))
              ngx.say(key, ": ", val)
            end
          end
          --[[
          The values of each property inside the replace, add or delete keys
          MUST be an array, even if there is only a single value.
          --]]
          if replaceItems['content'] then
            local content = replaceItems['content'] 
            -- replaceItems.content should be table
            if type(content) ~= 'table' then
              ngx.say("replaceItems.content should be table")
              ngx.say("exit TODO")
            end
            local newContent = table.concat(content, ", ")
            ngx.say(newContent)
            require('eXist').replaceContent( url )
          end
        end

        if args['delete'] then
          ngx.say("do delete")
        end

        if args['add'] then
          ngx.say("do add")
        end

      else
        ngx.say("TODO!")
      end
    elseif args['type'] then 
      local action = args['action']
    else
      ngx.say("TODO!")
    end


   -- postData = cjson.decode(ngx.req.get_body_data())
   --  hType = postData['type']
 end
end


function processGet()
  --ngx.say( ' process GET query to micropub endpoint ' )
  response = {}
  local msg = ''

  local args = ngx.req.get_uri_args()
  for key, val in pairs(args) do
    if type(val) == "table" then
      ngx.say(key, ": ", table.concat(val, ", "))
    else
     -- ngx.say(key, ": ", val)
    end
  end

  if args['q'] then
    --ngx.say( ' query the endpoint ' )
    local q = args['q']
    if q  == 'config' then
      -- 'https://www.w3.org/TR/micropub/#h-configuration'
      -- TODO!
      ngx.status = ngx.HTTP_OK 
      ngx.header.content_type = 'application/json' 
      ngx.say(cjson.encode(response))
      ngx.exit(ngx.OK)
    elseif q  == 'source' then
      ngx.status = ngx.HTTP_OK 
      -- TODO!
      ngx.say('TODO! https://www.w3.org/TR/micropub/#h-source-content')
      ngx.exit(ngx.OK)
    end
  end
end


function _M.processRequest()
  local host = ngx.req.get_headers()["Host"]
  --  the methods this endpoint can handle
  local method =  acceptMethods({"POST","GET"})

--[[
  get METHOD then branch

 --> POST
  - branch on hasMicroformatObjectType or hasAction request
--]]

if method == "POST" then
   processPost()
  else
    -- ngx.say(method)
    processGet()
  end

--[[

  CREATE: https://www.w3.org/TR/micropub/#create
   a 'POST' request that contains arg key 'h' 

  ACTION:
    a 'POST' request that contains arg key 'action' 
   
   actionTypes = {
   update = true,
   delete = true,
   undelete = true
   }

   updateTypes = {
    add = true,
    delete = true,
    replace = true
   }


  UODATE: https://www.w3.org/TR/micropub/#update



 - MUST support creating posts using the x-www-form-urlencoded syntax
 - MUST support creating posts with the [h-entry] vocabulary


--]] 
  --
  --  the microformat objects this endpoint can handle at the mo
  -- local data = {}
  -- ngx.req.read_body()
  -- if contentType  == 'application/x-www-form-urlencoded' then
  --   -- ngx.say(contentType)
  --    data  = processFormArgs()
  -- elseif contentType  == 'application/json' then
  --  -- postData = cjson.decode(ngx.req.get_body_data())
  --  --  hType = postData['type']
 -- end

 -- require('eXist').putXML(data)

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
