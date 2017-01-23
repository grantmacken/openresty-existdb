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

local extensions = {
png = 'image/png',
jpg = 'image/jpeg',
jpeg = 'image/jpeg',
gif = 'image/gif'
}

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

postedEntryProperties= {
  ['name'] = true,
  ['summary'] = true,
  ['category'] = true,
  ['rsvp'] = true,
  ['in-reply-to'] = true,
  ['repost-of'] = true,
  ['like-of'] = true,
  ['video'] = true,
  ['photo'] = true,
  ['content'] = true,
  ['published'] = false,
  ['updated'] = false
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
 note = 'n',
 article = 'a',
 photo = 'p',
 media = 'm'
}

local longKindOfPost = {
 n = 'note',
 a = 'article',
 p = 'photo',
 m = 'media'
}


local reqargsOptions = {
  timeout          = 1000,
  chunk_size       = 4096,
  max_get_args     = 100,
  mas_post_args    = 100,
  max_line_size    = 512,
  max_file_uploads = 10
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


function discoverPostType(props)
  -- https://www.w3.org/TR/post-type-discovery/
  local kindOfPost = 'note'
  for key, val in pairs(props) do
    -- ngx.say(key)
    if key == "rsvp" then
      --TODO check valid value
      kindOfPost = 'RSVP'
    elseif key == "in-reply-to" then
      --TODO check valid value
      kindOfPost = 'reply'
    elseif key == "repost-of" then
      --TODO check valid value
      kindOfPost = 'share'
    elseif key == "like-of" then
      --TODO check valid value
      kindOfPost = 'like'
    elseif key == "video" then
      --TODO check valid value
      kindOfPost = 'video'
    elseif key == "photo" then
      --TODO check valid value
      kindOfPost = 'photo'
      break
    elseif key == "name" then
      --TODO check valid value
      kindOfPost = 'article'
      break
    else
      kindOfPost = 'note'
    end
  end
 return kindOfPost
end

-- local function extractCategory( cat )
--   -- short urls https://gmack.nz/xxxxx

--   return sCat
-- end

-- Main entry point

function _M.processRequest()
  --  the methods this endpoint can handle
  local method =  acceptMethods({"POST","GET"})
  -- ngx.say(method)
  if method == "POST" then
    processPost()
  else
    processGet()
  end
end

function processGet()
  --ngx.say( ' process GET query to micropub endpoint ' )
  ngx.header.content_type = 'application/json' 
  local response = {}
  local msg = ''

  local args = ngx.req.get_uri_args()
  local domain = ngx.var.http_Host
  local mediaEndpoint = 'https://' .. domain .. '/micropub'
  if args['q'] then
    -- ngx.say( ' query the endpoint ' )-
    local q = args['q']
    if q  == 'config' then
      -- 'https://www.w3.org/TR/micropub/#h-configuration'
      -- TODO!
      local status = ngx.HTTP_OK 
      -- response = { 'media-endpoint' =  mediaEndpoint}
      local json = cjson.encode({
         [ 'media-endpoint' ]  = mediaEndpoint
        })
      ngx.print(json)
      ngx.exit(status)
    elseif q  == 'source' then
      ngx.status = ngx.HTTP_OK 
      -- TODO!
      -- ngx.say('https://www.w3.org/TR/micropub/#h-source-content')
      if args['url'] then
        local url = args['url']
        ngx.say( 'has url: ' , url  )

        local data =  require('mod.eXist').fetchPostsDoc( url )
        -- local xml = require 'xml'
        -- local d =  xml.load( data ) 
      else 
      msg = 'source must have associated url'
      return requestError(
        ngx.HTTP_NOT_ACCEPTABLE,
        'not accepted',
        msg )
      end
      ngx.exit(ngx.OK)
    elseif q  == 'syndicate-to' then
      ngx.status = ngx.HTTP_OK 
      -- https://github.com/bungle/lua-resty-libcjson
      -- https://github.com/bungle/lua-resty-libcjson/issues/1
      --  ngx.print(cjson.encode(json.decode('{"syndicate-to":[]}'))) 
     local json = '{"syndicate-to":[]}'
     ngx.print(json)
      ngx.exit(ngx.OK)
    end
  end
  ngx.status = ngx.HTTP_OK 
  -- TODO!
  ngx.say('You may query the endpoint using q pararm')

  ngx.exit(ngx.OK)
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


    --  Post object ref: http://microformats.org/wiki/microformats-2#v2_vocabularies
    --  TODO if no type is specified, the default type [h-entry] SHOULD be used.

    if hType == 'entry' then
      -- ngx.say( 'Create Entry ' )

      local domain = ngx.var.site
      local reqargs = require "resty.reqargs"
      local get, post, files = reqargs( reqargsOptions )
      if not get then
        error(post)
      end

      local properties = createMicroformatproperties( post )

      -- serialise as mf2 object
      local jData = { 
        ['type']  =  'h-' ..  hType,
        ['properties'] = properties
      }
     --  ngx.say( cjson.encode(jData) ) 
      local ret = require('mod.eXist').restxqMicropubRequest( jData )

      -- ngx.say( jData.type)
      -- ngx.say( jData.properties.url[1] )
      -- ngx.say( jData.properties.uid[1] )
      -- rewrite ^/?(.*)$ /exist/restxq/$host/$1 break;

      -- local data = createXmlEntry( jData )
      -- ngx.say(require('xml').dump( xData))
     -- ngx.say( location )
     -- ngx.header.location = jData.properties.url[1]
     -- ngx.status = ngx.HTTP_CREATED
     -- ngx.header.content_type = 'application/xml'
     -- local reason =  require('mod.eXist').postJSON( 'posts', jData )
     -- if reason == 'Created' then

     --   ngx.exit(ngx.HTTP_CREATED)
     -- end
     -- local reason =  require('mod.eXist').putXML( 'posts', data )
     -- if reason == 'Created' then
     --   ngx.say(require('xml').dump( xData))
     --   ngx.exit(ngx.HTTP_CREATED)
     -- end
    end
  elseif args['action'] then
   --  ngx.say( ' assume we are modifying a post item in some way'  )
   --  ngx.say ('TODO!')
    processActions( 'form' , args )
  else
    msg = "failed to get actionable POST argument, h or action required"
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
end

function createMicroformatproperties( post )

  --[[
    convert post data into a mf2 JSON  Serialization Formati

    NOTE: could use simplified
    JF2 Post Serialization Format  ref:  https://www.w3.org/TR/jf2/
    instead

  -- Post Properties
  -- https://www.w3.org/TR/jf2/#post-properties
  --
  server added microformat properties
  * published
  * url
  * uid

   uid and url  https://indieweb.org/u-uid

   uid an id to be used when deleting and undeleting posts
   http://microformats.org/wiki/uid-brainstorming
   A UID SHOULD be a URL rather than MUST
   The UID microformat will ordinarily be a URL,
   but it should be flexible enough to allow it to contain non-network resolvable URI

   my uid is resolvable by base domain
   https://{DOMAIN}/{UID}
   https://gmack.nz/n

  --  TODO! make url the expanded (human readable ) url
  --  e.g. /2017/01/01/title

  --]]

  -- ' from the sent properties - discovery the kind of post '
  local kindOfPost = discoverPostType( post )
  local properties = {}
  local sID = require('mod.postID').getID( getShortKindOfPost(kindOfPost))
  local sURL = 'https://' .. ngx.var.site .. '/' .. sID  
  local sPub, n, err =  ngx.re.sub(ngx.localtime(), " ", "T")

  properties['published'] =  { sPub }
  properties['uid'] =  { sID  }
  properties['url'] = { sURL }

  for key, val in pairs( post ) do
    -- ngx.say( 'post key: '  .. key  )
    -- ngx.say( type( val ) )
    if key == 'content' then
      if type(post['content'][1]) == "table" then
        for k, v in pairs(post['content'][1]) do
          ngx.say('TODO!')
          --table.insert(data,1,{ xml = 'content',['type'] = k, v })
        end 
      elseif type(post['content'][1]) == "string" then
        ngx.say('TODO!')
      elseif type(post['content']) == "string" then
        local content = {{
            ['value'] = post['content']
        }}
        properties['content'] = content
      end
    elseif key == 'content[html]' then
      if type(post['content[html]']) == "string" then
        local content = {{
            ['html'] = post['content[html]']
        }}
        properties['content'] = content
      end
    elseif key == 'content[value]' then
      if type(post['content[value]']) == "string" then
        local content = {{
            ['value'] = post['content[value]']
        }}
        properties['content'] = content
      end
    elseif  type(val) == "string" then
      local m, err = ngx.re.match(key, "\\[\\]")
      if m then
       local pKey, n, err = ngx.re.sub(key, "\\[\\]", "")
        if pKey then
          if postedEntryProperties[pKey] ~=  nil then
            if properties[ pKey ] ~= nil then
              -- ngx.say('key', ": ", pKey)
              table.insert(properties[ pKey ],val)
            else
              properties[ pKey ] = { val }
            end
          end
        end 
      else
        if err then
          ngx.log(ngx.ERR, "error: ", err)
          return
        end
        --  ngx.say("match not found")
        if postedEntryProperties[key] ~=  nil then
          properties[ key ] = { value }
        end
      end
    elseif type(val) == "table" then
      for k, v in pairs( val ) do
        local pKey, n, err = ngx.re.sub(key, "\\[\\]", "")
        if pKey then
          if postedEntryProperties[pKey] ~=  nil then
            if properties[ pKey ] ~= nil then
              -- ngx.say('key', ": ", pKey)
              table.insert(properties[ pKey ],v)
            else
              properties[ pKey ] = { v }
            end
          end
        end 
      end
    end
  end
 return properties
 end

 function createXmlEntry( jData )
   local xml = require 'xml' 
   local m, err = ngx.re.match( jData.type, "[^-]+$")

   xData = { 
     xml = m[0] 
   }

  for key, val in pairs( jData.properties ) do
    -- ngx.say('key', ": ", key)
    -- ngx.say( 'value type: ' ..  type(val))
    for k, v in pairs( val ) do
      if type(v) == "table" then
        table.insert( xData,1,{ xml = key })
        for ky, vl in pairs( v ) do
          -- ngx.say('key', ": ", key)
          -- ngx.say('key', ": ", ky)
          --  ngx.say( 'value type: ' ..  type(vl))
          -- local xContent = xml.find( xData, key )
          -- NOTE: TODO! url escape vl
          if type(vl) == "string" then
            table.insert(xml.find( xData, key ) ,1,{ xml = ky, ngx.encode_base64(vl)})
          end
        end
      else
        table.insert( xData,1,{ xml = key, v })
      end
    end
  end
  return xData
end

function createEntryFromJson( hType , props)
  local host = ngx.req.get_headers()["Host"]
  local data = {} -- the xml based table to return

  -- Post Properties
  -- https://www.w3.org/TR/jf2/#post-properties
  local kindOfPost = discoverPostType( props )
  -- top level entry
  data = { 
    xml = hType, 
    kind = kindOfPost
  }
  local properties = {}
  for key, val in pairs(props) do
    if type(val) == "table" then
      if key ~= 'content' then
        if postedEntryProperties[key] ~=  nil then
          if type(val) == "table" then
           for k, v in pairs( val ) do
             table.insert(data,1,{ xml = key, v })
           end
          end
        else
          return requestError(
            ngx.ngx.HTTP_BAD_REQUEST,
            'Bad Request',
            'TODO! add unknown props') 
        end
      end
    else
      -- all props should be array
    return requestError(
      ngx.ngx.HTTP_BAD_REQUEST,
      'Bad Request',
      'properties should be in an array') 
    end
  end


  properties['published'] = ngx.today()
  properties['id'] = require('mod.postID').getID( getShortKindOfPost(kindOfPost))
  properties['url'] = 'https://' .. host ..  '/' .. properties['id']

  for key, val in pairs(properties) do
    table.insert(data,1,{ xml = key, val })
  end

  -- ngx.say('content: ' ..  type(props['content'][1]) )
  if type(props['content'][1]) == "table" then
    for k, v in pairs(props['content'][1]) do
      table.insert(data,1,{ xml = 'content',['type'] = k, v })
    end 
  elseif type(props['content'][1]) == "string" then
    table.insert(data,1,{ xml = 'content',['type'] = 'text', props['content'][1]})
  end

  return properties['url'] ,  data
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
  local contentType = ngx.var.http_content_type
  local from, to, err = ngx.re.find(contentType ,"(multipart/form-data)")
  if from then
    contentType =  'multipart/form-data'
  end

  if not contains(contentTypes,contentType)  then
    local msg = 'endpoint does not accept' .. contentType
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg )
  end
  return contentType
end

function acceptFormFields(fields , field)
  --  the multpart form fields  this endpoint can handle
  if not contains( fields, field )  then
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      'endpoint only doesnt accept' .. field )
  end
 return method  
end

function processJsonBody( )
  ngx.req.read_body()
  local args  = cjson.decode(ngx.req.get_body_data())
  -- either 'ACTION' to modify post or 'TYPE' to create type of post
  if args['action'] then 
    -- ngx.say( 'action' )
    processActions( 'json' , args) 
  elseif args['type'] then
    processJsonTypes(args)
  end
end

function processJsonTypes(args)
  -- ngx.say( ' assume we are creating a post item'  )
  if type(args['type']) == 'table' then
    local jType = table.concat(args['type'], ", ")
    local hType, n, err = ngx.re.sub(jType, "h-", "")
   --  ngx.say(hType)
    if hType then
      if not microformatObjectTypes[hType] then
        msg = 'can not handle microformat  object type": ' .. hType
        return requestError(
          ngx.HTTP_NOT_ACCEPTABLE,
          'not accepted',
          msg )
      end
      -- TYPE ENTRY
      if hType == 'entry' then
        if type(args['properties']) == 'table' then
          -- ngx.say( 'CREATE ' ..  hType)
          local location, data = createEntryFromJson( hType , args['properties'] )
          -- ngx.say( location  )
          -- ngx.say(require('xml').dump(data))
          ngx.header.location = location
          ngx.status = ngx.HTTP_CREATED
          ngx.header.content_type = 'application/xml'
          local reason =  require('mod.eXist').putXML( 'posts',  data )
          if reason == 'Created' then
             ngx.say(require('xml').dump(data))
            ngx.exit(ngx.HTTP_CREATED)
          end
          -- require('mod.eXist').putXML('posts', data)
        end
      end
    end
  end
end


-- ACTIONS 
-- processing form actions
-- processing json actions

function processActions( postType, args )
  --[[
  --postType form or json 
    To update an entry, send "action": "update" and specify the URL of the entry that is being updated using the "url"
    property. The request MUST also include a replace, add or delete property (or any combination of these) containing
      the updates to make.
    --]]

  local action = args['action']
  local url = args['url']
  -- TODO! gen err if no action and or url
  --start of ACTION UPDATEs
  if action == 'update' then
    -- ngx.say(action)
    if url == nil then
      return requestError(
        ngx.HTTP_NOT_ACCEPTABLE,
        'HTTP not acceptable',
        'update action must have a URL')
    end

    -- do any combination
    --[[
          The values of each property inside the replace, add or delete keys MUST be an array, even if there is only a
          single value.
          --]]
    -- ACTION UPDATE REPLACE
    if args['replace'] then
      -- ngx.say("do replace")
      -- TODO! replace other properties
      if type(args['replace'] ) == 'table' then
        if type(args['replace']['content']) == 'table' then
          local property = 'content'
          local item = table.concat(args['replace']['content'], " ")
          -- TODO! for each item
          require('mod.eXist').replaceProperty( url, property, item )
        else
          return requestError(
            ngx.HTTP_BAD_REQUEST,
            'HTTP BAD REQUEST',
            'content value should be in an array')
        end
      else
        return requestError(
          ngx.HTTP_BAD_REQUEST,
          'HTTP BAD REQUEST',
          'replace value should be in an array')
      end
    end
    -- ACTION UPDATE DELETE
    if args['delete'] then
      --  ngx.say("do delete")
      -- ngx.say( args['delete'] ) 
      --  ngx.say( type( args['delete']) ) 
      -- TODO! replace other properties
      --local n = #args['delete']
      for key, property in pairs(args['delete']) do
        -- ngx.say( type(key) ) 
        -- ngx.say( type(property) ) 
        if type(key) == 'number' then
          -- should not happen
          -- ngx.say(key)
          --  ngx.say(property)
        elseif type(key) == 'string' then
          -- ngx.say(key)
          --ngx.say( type(property) ) 
          if type(property) == 'table' then
            for index, item in ipairs (property) do
              local reason =  require('mod.eXist').removePropertyItem( url, key , item )
              if reason == 'OK' then
                --  ngx.say(reason)
                require('mod.eXist').fetchPostsDoc( url )
              end
            end
          elseif type(property) == 'string' then
            local reason =  require('mod.eXist').removeProperty( url, property )
            if reason == 'OK' then
              require('mod.eXist').fetchPostsDoc( url )
            end
          end

        end
      end
    end
    -- ACTION UPDATE ADD
    if args['add'] then
      --  ngx.say("do add")
      --  TODO add more properties
      if type(args['add']['category']) == 'table' then
        local property = 'category'
        local item = table.concat(args['add']['category'], " ")
        -- ngx.say(item)
        require('mod.eXist').addProperty( url, property, item )
      end
    end
    -- end of ACTION UPDATEs
  elseif action == 'delete' then
    -- start of ACTION DELETE
    -- ngx.say("delete")
    local reason =  require('mod.eXist').deletePost( url )
    if reason == 'OK' then
      ngx.status = ngx.HTTP_NO_CONTENT
      ngx.exit( ngx.HTTP_NO_CONTENT )
    end
  elseif action == 'undelete' then
    -- start of ACTION UNDELETE
    -- ngx.say("undelete")
    local reason =  require('mod.eXist').undeletePost( url )
    if reason == 'OK' then
      ngx.status = ngx.HTTP_OK
      ngx.exit( ngx.HTTP_OK )
    end
  end
end

function processPost()
  -- ngx.say('the content-types this endpoint can handle')
  local contentType = acceptContentTypes({
      'application/json',
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    })
  --  ngx.say( contentType )
  if contentType  == 'application/x-www-form-urlencoded' then
    processPostArgs()
  elseif contentType  == 'multipart/form-data' then
    -- ngx.say( contentType )
    processMultPartForm()
  elseif contentType  == 'application/json' then
    processJsonBody()
  end
end

function processMultPartForm()
  local msg = ''

  -- ngx.say( 'process MultPart Form' )

  local reqargs = require "resty.reqargs"
  local get, post, files = reqargs( reqargsOptions )
   if not get then
    error(post)
  end

  -- ngx.say( 'files' )
  -- this is like the php files array
  for key, val in pairs(files) do
    if type(val) == "table" then
     -- ngx.say('key', ": ", key)
     -- ngx.say( 'value type: ' ..  type(val))
     --  for k, v in pairs( val ) do
     --    ngx.say('k', ": ", k)
     --    ngx.say( 'v: ' ..  v)
     --  end
     --  ngx.say('-------------------------')

      -- id prefix always M
      local ext, mimeType = getMimeType( val.file )
      local sID = require('mod.postID').getID( 'm' )
      local mediaFileName = ngx.re.sub(sID, "^m", "M") ..  '.' .. ext 
      local data = { 
        xml = 'media'
      }

      local properties = {}
      properties['name']      = val.file
     --  properties['size']      = val.size
      properties['uploaded']  = ngx.today()
      -- properties['signature'] = ngx.md5(part_body)
      properties['mime']      = mimeType
      -- id prefix always M
      properties['id']  = sID
      properties['url'] = 'https://' .. ngx.var.host .. '/' .. sID
      properties['src'] = 'https://' .. ngx.var.host .. '/' .. mediaFileName
      for k, v in pairs(properties) do
       -- ngx.say(type(v))
       -- ngx.say(k, ": ", v)
        table.insert(data,1,{ xml = k, v })
      end
      local reason =  require('mod.eXist').putMedia( read( val.temp ),  mediaFileName , mimeType )
      if reason == 'Created' then
        -- NOTE: return binary source as location
        ngx.header.location = properties['src']
        -- Note create a doc for the 'shoebox
        local reason2 =  require('mod.eXist').putXML( 'uploads',  data )
        if reason2 == 'Created' then
          -- ngx.say(require('xml').dump(data))
          ngx.exit(ngx.HTTP_CREATED)
        end
      end
    else
      ngx.say('key', ": ", key)
    end
  end
  -- ngx.say( 'post ')

  -- for key, val in pairs(get) do
  --   if type(val) == "table" then
  --      ngx.say('key', ": ", key)
  --      ngx.say( 'value type: ' ..  type(val))
  --      for k, v in pairs( val ) do
  --      ngx.say('key', ": ", k)
  --      ngx.say( 'value type: ' ..  v)
  --      end

  --   else
  --      ngx.say('key', ": ", key)
  --   end
  -- end

  -- ngx.say( 'get' )

  -- for key, val in pairs(post) do
  --   if type(val) == "table" then
  --      ngx.say('key', ": ", key)
  --      ngx.say( 'value type: ' ..  type(val))
  --      for k, v in pairs( val ) do
  --      ngx.say('key', ": ", k)
  --      ngx.say( 'value type: ' ..  v)
  --      end
  --   else
  --      ngx.say('key', ": ", key)
  --   end
  -- end

end

function xprocessMultPartForm()
    --  mod.parser is lua-resty-multipart-parser - Simple multipart data parser for OpenResty/Lua
  --  from agentzha TODO! check if avaible on OPM
  --  @see https://github.com/agentzh/lua-resty-multipart-parser
  local parser = require "mod.parser" 
  ngx.req.read_body()
  local body = ngx.req.get_body_data()
  local p, err = parser.new(body, ngx.var.http_content_type)
  if not p then
    msg = "failed to create parser: ", err
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end

  while true do
    local part_body, name, mime, filename = p:parse_part()
    if not part_body then
      break
    end
    -- ngx.say("== part ==")
    -- ngx.say("name: [", name, "]")
    -- ngx.say("file: [", filename, "]")
    -- ngx.say("mime: [", mime, "]")
    if not filename then
      return requestError(
        ngx.HTTP_BAD_REQUEST,
        'no filename',
        'submitted data in form does not have required fields' )
    end
    if name ~= 'file'  then
      return requestError(
        ngx.HTTP_BAD_REQUEST,
        'no file',
        'submitted data in form does not have required fields' )
    end

    local ext, mimeType = getMimeType( filename )
    local sID = require('mod.postID').getID( 'm' )
    local mediaFileName = ngx.re.sub(sID, "^m", "M") ..  '.' .. ext 
    local data = { 
      xml = 'media'
    }

    local properties = {}
    properties['name']      = filename
    properties['uploaded']  = ngx.today()
    properties['signature'] = ngx.md5(part_body)
    properties['mime']      = mimeType
    -- id prefix always M
    properties['id']  = sID
    properties['url'] = 'https://' .. ngx.var.host .. '/' .. sID
    properties['src'] = 'https://' .. ngx.var.host .. '/' .. mediaFileName
    for key, val in pairs(properties) do
      -- ngx.say(type(val))
      -- ngx.say(key, ": ", val)
      table.insert(data,1,{ xml = key, val })
    end
    local reason =  require('mod.eXist').putMedia( part_body,  mediaFileName , mimeType )
    if reason == 'Created' then
      -- NOTE: return binary source as location
      ngx.header.location = properties['src']
      -- Note create a doc for the 'shoebox
      local reason2 =  require('mod.eXist').putXML( 'uploads',  data )
      if reason2 == 'Created' then
        ngx.say(require('xml').dump(data))
        ngx.exit(ngx.HTTP_CREATED)
      end
    end
  end
end


--[[

    -- ngx.say( ext )
    -- ngx.say( mimeType )
    -- ngx.say( sID )
    -- ngx.say( mediaFileName )
    -- if not mimeType then
    --   break
    -- end


    --  ngx.say("mimeType: [", mimeType, "]")
    -- local md5 =  ngx.md5(part_body)
    --  ngx.say("md5:  [", md5, "]")

    -- top level entry
    -- local data = { 
    --   xml = 'entry', 
    --   type = 'photo'
    -- } 

    -- top level entry
    -- http://microformats.org/wiki/hmedia
    -- https://indieweb.org/Shoebox

    --[[
  shoebox idea  - a collection of 'findable'  media items

  accept publishing photos 
   - photos -  images 

   media-info like atomPub media-edit


  media  properties

  upon upload create hMedia entry

  name        original file name

  id         [m][DATE][i]  
           shortKindOfPost |  base60Date | incremented integer representing item published that day
  signature -- a md5 signiture to prevent storing\uploading of same photoi
               A file's unique identifier is the hash of its contents
  published  date
  mime       resource stored as content-type & http response/request as ...


 after upload 
  you can add/edit/delete media entry properties

  -- name      
  -- summary    
  -- category -- tags

  property values can be used in HTML templates

  summary     : figure figcaption text
  name        : img alt attribute text ( defaults to upload filename )
  id          : img src attribute text

https://developer.mozilla.org/en-US/docs/Web/HTML/Element/figure

search for items in shoebox collection by
 - date  (resent items)
 - contains  string in 'name or summary'
 - tag

--]]

  --[[
  - all props is sent json should be a lua table 
  @see  https://www.w3.org/TR/micropub/#h-json-syntax
  When creating posts in JSON format, all values MUST be specified as arrays, even if there is only one value, identical
  to the Microformats 2 JSON format. This request is sent with a content type of application/json.

#CONTENT NODES

  If the source of the post was written as HTML content, then the endpoint MUST return the content property as an object
  containing an html property. Otherwise, the endpoint MUST return a string value for the content property, and the
  client will treat the value as plain text. This matches the behavior of the values of properties in
  [microformats2-parsing].

json content as plain text

  "content": ["hello world"]

json content as html

 "content": [{ "html": "<b>Hello</b> <i>World</i>" } ]

json content as text 

 "content": [{ "text": "hello world" } ]

in converting to xml follow atom syntax

 <content type="text">hello world</content>

 <content type="html">"<b>Hello</b> <i>World</i>"</content>

--]]


return _M
