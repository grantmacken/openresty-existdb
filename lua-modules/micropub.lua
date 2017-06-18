local _M = {}

local util = require('grantmacken.util')
local cfg  = require('grantmacken.config')



--UTILITY TODO move to utility.lua
-- function requestError( status, msg ,description)
--   ngx.status = status
--   ngx.header.content_type = 'application/json'
--   local json = cjson.encode({
--       error  = msg,
--       error_description = description
--     })
--   ngx.print(json)
--   ngx.exit(status)
-- end

-- local extensions = {
-- png = 'image/png',
-- jpg = 'image/jpeg',
-- jpeg = 'image/jpeg',
-- gif = 'image/gif'
-- }

-- function read(f)
--   local open     = io.open
--   local f, e = open(f, "rb")
--   if not f then
--     return nil, e
--   end
--   local c = f:read "*a"
--   f:close()
--   return c
-- end

-- function getMimeType( filename )
--   -- get file extension Only handle 
--   local ext, err = ngx.re.match(filename, "[^.]+$")
--   if ext then
--    return ext[0], extensions[ext[0]]
--   else
--     if err then
--       ngx.log(ngx.ERR, "error: ", err)
--       return
--     end
--     ngx.say("match not found")
--   end
-- end

-- function extractID( url )
--   -- short urls https://gmack.nz/xxxxx
--   local sID, err = require("ngx.re").split(url, "([na]{1}[0-9A-HJ-NP-Z_a-km-z]{4})")[2]
--   if err then 
--     return requestError(
--       ngx.HTTP_SERVICE_UNAVAILABLE,
--       'HTTP service unavailable',
--       'connection failure')
--   end
--   return sID
-- end

-- https://www.w3.org/TR/micropub/#h-reserved-properties
-- note reserved extension mp-* 

-- local reservedPostPropertyNames = {
--   access_token = true,
--   h = true,
--   q = true,
--   action = true,
--   url = true
-- }



-- function contains(tab, val)
--   for index, value in ipairs (tab) do
--     if value == val then
--       return true
--     end
--   end
--   return false
-- end


--[[
3.8 Error Response
https://www.w3.org/TR/micropub/#error-response
--]]



 -- https://www.w3.org/TR/micropub/#create
 --  handle these microformat Object Types
 --  TODO!  mark true when can handle
 ---
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
  ['syndicate-to'] = true,
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
 reply = 'r',
 article = 'a',
 photo = 'p',
 media = 'm'
}

local longKindOfPost = {
 n = 'note',
 r = 'reply',
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


function discoverPostType(props)
  -- https://www.w3.org/TR/post-type-discovery/
  local kindOfPost = 'note'
  if props['in-reply-to'] ~= nil then
    kindOfPost = 'reply'
  end
  -- for key, val in pairs(props) do
  --   ngx.log(ngx.INFO, "key: ", key)
  --   ngx.log(ngx.INFO, "key: ", type( key ))
  --   if key == "rsvp" then
  --     --TODO check valid value
  --     kindOfPost = 'RSVP'
  --   elseif key == 'in%-reply%-to' then
  --     --TODO check valid value
  --     kindOfPost = 'reply'
  --   elseif key == 'repost%-of' then
  --     --TODO check valid value
  --     kindOfPost = 'share'
  --   elseif key == 'like%-of' then
  --     --TODO check valid value
  --     kindOfPost = 'like'
  --   elseif key == "video" then
  --     --TODO check valid value
  --     kindOfPost = 'video'
  --   elseif key == "photo" then
  --     --TODO check valid value
  --     kindOfPost = 'photo'
  --     break
  --   elseif key == "name" then
  --     --TODO check valid value
  --     kindOfPost = 'article'
  --     break
  --   else
  --     kindOfPost = 'note'
  --   end
  -- end
 return kindOfPost
end
-- Main entry point

function _M.processRequest()
  ngx.log( ngx.INFO, 'Process Request for '  .. cfg.get('domain') )
  local method =  util.acceptMethods({"POST","GET"})
  ngx.log( ngx.INFO, 'Accept Method: ' .. method )
  if method == "POST" then
     processPost()
  else
    --  processGet()
  end
end

function processPost()
  local contentType = util.acceptContentTypes({
      'application/json',
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    })

  ngx.log( ngx.INFO, 'Accept Content Type: ' .. contentType )
  if contentType  == 'application/x-www-form-urlencoded' then
     processPostArgs()
  elseif contentType  == 'multipart/form-data' then
    -- processMultPartForm()
  elseif contentType  == 'application/json' then
    -- processJsonBody()
  end
end



function processPostArgs()
  ngx.log(ngx.INFO, ' ======================' )
  ngx.log(ngx.INFO, ' process POST arguments ' )
  ngx.log(ngx.INFO, ' ======================' )
  local msg = ''
  local args = {}
  ngx.req.read_body()
  local reqargs = require "resty.reqargs"
  local get, post, files = reqargs(  )
  if not get then
    msg = "failed to get post args: " ..  err
    return util.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
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
    --ngx.log(ngx.INFO, ' - count post args ' .. getItems )
    args = get
  end

  if  postItems > 0 then
    --ngx.log(ngx.INFO, ' - count post args ' .. postItems )
    args = post
  end

  -- ngx.log(ngx.INFO, 'args')
  -- for key, val in pairs(args) do
  --   if type(val) == "table" then
  --     ngx.log(ngx.INFO,'key', ": ", key)
  --     ngx.log(ngx.INFO, 'value type: ' ..  type(val))
  --     for k, v in pairs( val ) do
  --       --ngx.log(ngx.INFO,'key', ": ", k)
  --       --ngx.log(ngx.INFO, 'value type: ' ..  v)
  --     end
  --   else
  --     ngx.log(ngx.INFO,'key', ": ", key)
  --   end
  -- end

  if args['h'] then
    local hType = args['h']
    if microformatObjectTypes[hType] then
      ngx.log(ngx.INFO,  ' - assume we are creating a post item'  )
    else
      msg = 'can not handle microformat  object type": ' .. hType
      return util.requestError(
        ngx.HTTP_NOT_ACCEPTABLE,
        'not accepted',
        msg )
    end

    -- ngx.log(ngx.INFO,  'Microformat Object Type: ' .. args['h'] )
    -- --  Post object ref: http://microformats.org/wiki/microformats-2#v2_vocabularies
    -- --  TODO if no type is specified, the default type [h-entry] SHOULD be used.
    if hType == 'entry' then
      ngx.log(ngx.INFO, ' - create entry ' )
      ngx.log(ngx.INFO, ' - from the sent properties - discover the kind of post ')
      local kindOfPost = discoverPostType( post )
      -- ngx.log(ngx.INFO, 'kindOfPost: [ ' .. kindOfPost  .. ' ]')
      local properties, kindOfPost = createMf2Properties( args )
      local jData = { 
        ['type']  =  'h-' ..  hType,
        ['properties'] = properties
      }
      --ngx.log(ngx.INFO,  ' - post args serialised as mf2' )
      ngx.log(ngx.INFO,  ' - serialize jData as XML nodes and store in eXist db' )
      local uID = jData.properties.uid[1]
      -- tasks depends on type of post 
      local xmlEntry = createXmlEntry(jData)
      local uID = jData.properties.uid[1]
      local reason =  require('grantmacken.eXist').putXML( 'posts', uID, xmlEntry)
      ngx.log(ngx.INFO,  ' - stored resource "' .. uID .. '" into "posts" collection' )
      if kindOfPost == 'reply' then
        ngx.log(ngx.INFO,  kindOfPost  ..  ' additional tasks ' )
        -- my page 
        local source = jData.properties.url[1]
        -- TODO may have more than one in-reply-to
        local target = jData.properties['in-reply-to'][1]
        local endpoint = require('grantmacken.endpoint').discoverWebmentionEndpoint( target )
        if endpoint ~= nil then
          ngx.log(ngx.INFO, 'source: [ '  .. source .. ' ]' )
          ngx.log(ngx.INFO, 'target: [ '  .. target .. ' ]' )
          ngx.log(ngx.INFO, 'endpoint: [ '  .. endpoint .. ' ]' )
          local mention = sendWebMention( endpoint, source, target )
        else
          ngx.log(ngx.INFO, 'could NOT discover endpoint' )
        end 
      end
      -- Finally 
      if reason == 'Created' then
        ngx.log(ngx.INFO, ' created entry: ' .. jData.properties.url[1] )
        ngx.log(ngx.INFO, '# EXIT ...... # ' )
        ngx.header.location = jData.properties.url[1]
        ngx.exit(ngx.HTTP_CREATED)
      end
    end
  elseif args['action'] then
   ngx.log(ngx.INFO,  ' assume we are modifying a post item in some way'  )
    processActions( 'form' , args )
  else
    msg = "failed to get actionable POST argument, h or action required"
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
end


function createMf2Properties( post )
   ngx.log(ngx.INFO,  'Convert post data into a mf2 JSON Serialization Format' )
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

  ngx.log(ngx.INFO, ' - from the sent properties - discover the kind of post ')
  local kindOfPost = discoverPostType( post )
  ngx.log(ngx.INFO, 'kindOfPost: [ ' .. kindOfPost  .. ' ]')
  local properties = {}
  local sID = require('grantmacken.postID').getID( getShortKindOfPost(kindOfPost))
  local sURL = 'https://' .. cfg.get('domain') .. '/' .. sID
  local sPub, n, err =  ngx.re.sub(ngx.localtime(), " ", "T")

  properties['published'] =  { sPub }
  properties['uid'] =  { sID  }
  properties['url'] = { sURL }

  ngx.log(ngx.INFO, 'property: published - ' .. sPub )
  ngx.log(ngx.INFO, 'property: uid  - ' .. sID )
  ngx.log(ngx.INFO, 'property: url  - ' .. sURL )

  for key, val in pairs( post ) do
    -- ngx.log(ngx.INFO,  'post key: '  .. key  )
    -- ngx.log(ngx.INFO,   type( val ) )
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
      -- ngx.log(ngx.INFO,  'post key: '  .. key  )
      -- ngx.log(ngx.INFO,   type( val ) )
      -- categories are array like
      local m, err = ngx.re.match(key, "\\[\\]")
      -- ngx.log(ngx.INFO,   type( m ) )
      if m then
        local pKey, n, err = ngx.re.sub(key, "\\[\\]", "")
        if pKey then
          if postedEntryProperties[pKey] ~=  nil then
            if properties[ pKey ] ~= nil then
              ngx.log(ngx.INFO,  'pKey : '  .. pKey )
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
        -- ngx.log(ngx.INFO,   'match not found' )
        if postedEntryProperties[key] ~=  nil then
          -- ngx.log(ngx.INFO,  'non array key: '  .. key  )
          -- ngx.log(ngx.INFO,   val  )
          properties[ key ] = { val }
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
 return properties, kindOfPost
 end


 function createXmlEntry( jData )
   ngx.log(ngx.INFO,  'create XML entry from jData' )
   local root = ngx.re.match( jData.type, "[^-]+$")[0]
   local xmlNode = ''
   -- ngx.log(ngx.INFO,  'root documentElement: ' .. root   )
   local properties = {}
   local contents = {}
   for property, val in pairs( jData.properties ) do
     -- ngx.log(ngx.INFO, 'property', ": ", property)
     -- ngx.log(ngx.INFO, 'value type: ' ..  type(val))
     for i, item in pairs( val ) do
       if type(item) == "table" then
         -- ngx.log(ngx.INFO, cjson.encode(item) )
         --table.insert( xData,1,{ xml = key })
         for key, item2 in pairs( item ) do
           -- ngx.log(ngx.INFO,'key', ": ", key)
           -- ngx.log(ngx.INFO,'item2 type: ' ..  type(item2))
           if type(item2) == "string" then
             xmlNode =  '<' .. key .. '>' .. item2 .. '</' .. key .. '>'
             table.insert(contents,xmlNode)
           end
         end
         xmlNode =  '<' .. property .. '>' .. table.concat(contents) .. '</' .. property .. '>'
        table.insert(properties,xmlNode)
      else
         xmlNode =  '<' .. property .. '>' .. item .. '</' .. property .. '>'
        table.insert(properties,xmlNode)
      end
    end
  end
 local xmlDoc =  '<' .. root .. '>' .. table.concat(properties) .. '</' .. root .. '>'
  return xmlDoc
end

function processGet()
  ngx.log(ngx.INFO, 'process GET query to micropub endpoint' )
  ngx.header.content_type = 'application/json' 
  local response = {}
  local msg = ''

  local args = ngx.req.get_uri_args()
  local mediaEndpoint = 'https://' .. cfg.domain .. '/micropub'
  if args['q'] then
    ngx.log(ngx.INFO, ' query the endpoint ' )
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
      ngx.log(ngx.INFO, '- source query' )
      -- TODO!
      -- ngx.say('https://www.w3.org/TR/micropub/#h-source-content')
      if args['url'] then
        local url = args['url']
        ngx.log(ngx.INFO,  'has url: ' , url  )
        fetchPostsDoc( url )

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






--------------------------------
--TODO
--
--cleanup below
----------------------------------



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
  properties['id'] = require('grantmacken.postID').getID( getShortKindOfPost(kindOfPost))
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
  local from, to, err = ngx.re.find(contentType ,"(multipart/form-data|application/x-www-form-urlencoded|multipart/form-data)")
  if from then
    contentType =  string.sub(contentType, from, to)
  end
  if not contains(contentTypes,contentType)  then
    local msg = 'endpoint does not accept' .. contentType
    return requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted ',
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
          ngx.header['Location'] = location
          ngx.status = ngx.HTTP_CREATED
          ngx.header.content_type = 'application/xml'
          local reason =  require('grantmacken.eXist').putXML( 'posts',  data )
          if reason == 'Created' then
             ngx.say(require('xml').dump(data))
            ngx.exit(ngx.HTTP_CREATED)
          end
          -- require('grantmacken.eXist').putXML('posts', data)
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
  ngx.log(ngx.INFO, 'start of ACTION UPDATEs')
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
      ngx.log(ngx.INFO, "do replace")
      -- TODO! replace other properties
      if type(args['replace'] ) == 'table' then
        if type(args['replace']['content']) == 'table' then
          ngx.log(ngx.INFO, "do replace content")
          local property = 'content'
          local item = table.concat(args['replace']['content'], " ")
          -- TODO! for each item
          ngx.log(ngx.INFO, "url: " .. url)
          ngx.log(ngx.INFO, "property: " .. property)
          ngx.log(ngx.INFO, "item: " .. item)
          local reason = replaceProperty( url, property, item )
          if reason == 'OK' then
            ngx.status = ngx.HTTP_OK
            ngx.exit( ngx.HTTP_OK )
          end
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
      ngx.log(ngx.INFO, 'do action update DELETE')
      ngx.log(ngx.INFO, type(args['delete']) )
      local reason = nil
      -- -- TODO! replace other properties
      -- --local n = #args['delete']
      for key, property in pairs(args['delete']) do
        ngx.log(ngx.INFO, 'keyType:' .. type(key) ) 
        ngx.log(ngx.INFO, 'propType:' .. type(property) ) 
        if type(key) == 'number' then
          -- ngx.log(ngx.INFO, 'keyType:' .. key ) 
          -- ngx.log(ngx.INFO, 'property:' .. property ) 
          if type(property) == 'string' then
            local reason =  removeProperty( url, property)
          end
        elseif type(key) == 'string' then
          -- ngx.say(key)
          --ngx.say( type(property) ) 
          if type(property) == 'table' then
            for index, item in ipairs (property) do
              ngx.log(ngx.INFO, "url: " .. url)
              ngx.log(ngx.INFO, "key: " .. key)
              ngx.log(ngx.INFO, "item: " .. item)
              reason =  removePropertyItem( url, key , item )
            end
          elseif type(property) == 'string' then
            ngx.log(ngx.INFO, "url: " .. url)
            ngx.log(ngx.INFO, "key: " .. key)
            -- local reason =  require('grantmacken.eXist').removeProperty( url, property )
            -- if reason == 'OK' then
            --   require('grantmacken.eXist').fetchPostsDoc( url )
            -- end
          end
        end
      end
      ngx.log(ngx.INFO, 'end action update DELETE')
      if reason == 'OK' then
        ngx.status = ngx.HTTP_OK
        ngx.exit( ngx.HTTP_OK )
      end
    end
    -- ACTION UPDATE ADD
    if args['add'] then
      ngx.log(ngx.INFO, 'do action update ADD')
     local reason = nil 
     --  ngx.log(ngx.INFO, type(args['add']) ) 
      for key, property in pairs(args['add']) do
        -- ngx.log(ngx.INFO, 'keyType: '  .. type(key) ) 
        -- ngx.log(ngx.INFO, 'propType: ' .. type(property) ) 
        if type(key) == 'number' then
          ngx.log(ngx.INFO, 'TODO! key:' .. key ) 
        elseif type(key) == 'string' then
          --  ngx.log(ngx.INFO, 'key: ' .. key ) 
          if type(property) == 'table' then
            for index, item in ipairs (property) do
              ngx.log(ngx.INFO, "url: " .. url)
              ngx.log(ngx.INFO, "key: " .. key)
              ngx.log(ngx.INFO, "item: " .. item)
              reason =  addProperty( url, key, item )
            end
          end
        end
      end
      ngx.log(ngx.INFO, 'end action update ADD')
      if reason == 'OK' then
        ngx.status = ngx.HTTP_OK
        ngx.exit( ngx.HTTP_OK )
      end
    end
    -- end of ACTION UPDATEs
  elseif action == 'delete' then
    -- start of ACTION DELETE
    ngx.log(ngx.INFO, "start of ACTION DELETE")
    ngx.log(ngx.INFO, "URL: " .. url )
    local reason = deletePost( url )
    if reason == 'OK' then
      ngx.status = ngx.HTTP_NO_CONTENT
      ngx.exit( ngx.HTTP_NO_CONTENT )
    end
  elseif action == 'undelete' then
    ngx.log(ngx.INFO, "start of ACTION UNDELETE")
    local reason =  undeletePost( url )
    if reason == 'OK' then
      ngx.status = ngx.HTTP_OK
      ngx.exit( ngx.HTTP_OK )
    end
  end
end



function processMultPartForm()
  local msg = ''
  ngx.log(ngx.INFO, "process MultPart Form")
  if ngx.var.http2 ~= 'h2' then
    msg = 'Upload only done with HTTP1.1'
    ngx.log(ngx.INFO, msg)
  else
    ngx.log(ngx.INFO,  'http version 2 ' .. ngx.var.http2)
    msg = 'Upload only done with HTTP1.1'
    ngx.log(ngx.WARN, msg)
    requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
  end
  -- https://github.com/bungle/lua-resty-reqargs 
  local split = require( "ngx.re" ).split
  local reqargs = require "resty.reqargs"
  local get, post, files = reqargs( reqargsOptions )
  if not get then
    error(post)
  end

  ngx.log(ngx.INFO, 'FILES')
  -- for key, val in pairs(files) do
  --   if type(val) == "table" then
  --     ngx.log(ngx.INFO,'key', ": ", key)
  --     ngx.log(ngx.INFO, 'value type: ' ..  type(val))
  --     for k, v in pairs( val ) do
  --       ngx.log(ngx.INFO,'key', ": ", k)
  --       ngx.log(ngx.INFO, 'value type: ' ..  v)
  --     end
  --   else
  --     ngx.log(ngx.INFO,'key', ": ", key)
  --   end
  -- end

  local properties = {}
  for key, val in pairs(files) do
    if type(val) == "table" then
      local ext, mimeType = getMimeType( val.file )
      local sID = require('grantmacken.postID').getID( 'm' )
      local properties = {}
      properties[ 'mimeType' ] =  mimeType
      -- ngx.log(ngx.INFO,'key', ": ", key)
      -- ngx.log(ngx.INFO, 'value type: ' ..  type(val))
      properties['file']      = val.file
      properties['size']      = val.size
      properties['temp']      = val.temp
      properties['uploaded']  = ngx.today()
      properties['signature'] = ngx.md5(part_body)
      properties['mime']      = mimeType
      properties['extension'] = ext
      properties['id']        = sID
      properties['name']      = ngx.re.sub(sID, "^m", "M") ..  '.' .. ext
      properties['url']       = 'https://' .. cfg.domain .. '/' .. sID
      properties['src']       = 'https://' .. cfg.domain  .. '/' .. ngx.re.sub(sID, "^m", "M") ..  '.' .. ext

      ngx.log(ngx.INFO,     'file [ ' ..  properties.file      .. ' ]')
      ngx.log(ngx.INFO,     'mime [ ' ..  properties.mime      .. ' ]')
      ngx.log(ngx.INFO,     'temp [ ' ..  properties.temp      .. ' ]')
      ngx.log(ngx.INFO,     'size [ ' ..  properties.size      .. ' ]')
      ngx.log(ngx.INFO, 'uploaded [ ' ..  properties.uploaded  .. ' ]')
      ngx.log(ngx.INFO,'signature [ ' ..  properties.signature .. ' ]')
      ngx.log(ngx.INFO,'extension [ ' ..  properties.extension .. ' ]')
      ngx.log(ngx.INFO,'renamed   [ ' ..  properties.name .. ' ]')
      ngx.log(ngx.INFO,'doc id    [ ' ..  properties.id .. ' ]')
      ngx.log(ngx.INFO,'src       [ ' ..  properties.src .. ' ]')
      ngx.log(ngx.INFO,'url       [ ' ..  properties.url .. ' ]')

      local reason =  putMedia( properties )
      if reason == 'Created' then
        -- NOTE: return binary source as location
        -- Note create a doc for the 'shoebox
        local reason2 =  putXML2( 'uploads', properties )
        if reason2 == 'Created' then
          ngx.header['Location'] = properties['src']
          ngx.status = ngx.HTTP_CREATED
          ngx.exit(ngx.HTTP_CREATED)
        end
      end
    end
  end
end

--[[
deleting and undeleting posts
moves posts to and from a recycle collection ( like a trash/recycle bin )
on windows
--]]

function deletePost( uri )
  local contentType = 'application/xml'
  local resource    = extractID( uri) 
  local restPath  = '/exist/rest/db/apps/' .. cfg.domain 
  local sourceCollection = '/db/data/' .. cfg.domain .. '/docs/posts'
  local targetCollection = '/db/data/' .. cfg.domain .. '/docs/recycle'
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
  ngx.log(ngx.INFO, "status: ", response.status)
  ngx.log(ngx.INFO,"reason: ", response.reason)
  return response.reason
end

function undeletePost( uri )
  local contentType = 'application/xml'
  local resource    = extractID( uri) 
  local restPath  = '/exist/rest/db/apps/' .. cfg.domain 
  local sourceCollection = '/db/data/' .. cfg.domain .. '/docs/recycle'
  local targetCollection = '/db/data/' .. cfg.domain .. '/docs/posts'
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
  --  ngx.say(txt)
  local response =  sendMicropubRequest( restPath, txt )
  ngx.log(ngx.INFO, "status: ", response.status)
  ngx.log(ngx.INFO,"reason: ", response.reason)
  return response.reason
end

--[[
updating posts
 update actions
 - add
 - delete
 - replace

--]]

function addProperty( uri, property, item )
  local domain      = cfg.domain
  local resource    = extractID( uri )
  local contentType = 'application/xml'
  -- TODO only allow certain properties
  local xmlNode =  '<' .. property .. '>' .. item .. '</' .. property .. '>'
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local docPath   = '/db/data/' .. domain .. '/docs/posts/' .. resource
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    let $node := ]] .. xmlNode .. [[
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
  local response =  sendMicropubRequest( restPath, txt )
  ngx.log(ngx.INFO, "status: ", response.status)
  ngx.log(ngx.INFO,"reason: ", response.reason)
  return response.reason
end

function replaceProperty( uri, property, item )
  local domain      =  cfg.domain
  local resource    = extractID( uri)
  --local xml = require 'xml'
  local contentType = 'application/xml'
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local docPath   = '/db/data/' .. domain .. '/docs/posts/' .. resource
  local xmlNode = ''
  -- TODO only allow certain properties
  if property == 'content' then
    xmlNode = '<value>' .. item .. '</value>'
  else
   -- xmlNode = { xml = property, item } 
  end

  -- ngx.say(xml.dump(xmlNode))

  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    let $node := ]] .. xmlNode .. [[
    let $item := ']] .. item .. [['
    return
    if ( exists( $document/entry/]] .. property .. [[/value)) then (
      update replace $document/entry/]] .. property .. [[/value with $node )
    else (
      update insert $node into $document/entry
    )

    ]] ..']]>' .. [[ 
    </text>
  </query>
]]
  local response =  sendMicropubRequest( restPath, txt )
  ngx.log(ngx.INFO, "status: ", response.status)
  ngx.log(ngx.INFO,"reason: ", response.reason)
  return response.reason
end


function removeProperty( uri, property)
  local domain      = cfg.domain
  local resource    = extractID( uri) 
  local contentType = 'application/xml'
  local restPath  = '/exist/rest/db/apps/' .. domain 
  local docPath   = '/db/data/' .. domain .. '/docs/posts/' .. resource
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
  local response =  sendMicropubRequest( restPath, txt )
  ngx.log(ngx.INFO, "status: ", response.status)
  ngx.log(ngx.INFO,"reason: ", response.reason)
  return response.reason
end

function removePropertyItem( uri, property, item )
  local contentType = 'application/xml'
  local domain      = cfg.domain
  local resource    = extractID( uri) 
  -- TODO only allow certain properties
  -- ngx.say( resource )
  -- ngx.say( property )
  -- ngx.say( item )
  local xmlNode =  '<' .. property .. '>' .. item .. '</' .. property .. '>'
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
    return
    if ( $document/entry/]] .. property .. '[ . = "' .. item .. '" ]' ..  [[ ) then (
    update delete  $document/entry/]] .. property .. '[ . = "' .. item .. '" ]' ..  [[
    )
    else ( )
    ]] ..']]>' .. [[ 
    </text>
  </query>
]]
  -- ngx.log(ngx.INFO, txt)
  local response =  sendMicropubRequest( restPath, txt )
  ngx.log(ngx.INFO, "status: ", response.status)
  ngx.log(ngx.INFO,"reason: ", response.reason)
  return response.reason
end

function fetchPostsDoc( uri )
  ngx.log(ngx.INFO, "fetch posts doc ")
  local contentType = 'application/json'
  local authorization = cfg.auth
  local domain      = cfg.domain
  local txt    =    extractID( uri )
  ngx.log(ngx.INFO, "ID: " .. txt)
  local restPath  = '/exist/rest/db/apps/' .. cfg.domain
  local target  =  restPath .. '/modules/api/mp-source.xq'
  ngx.log(ngx.INFO, "path:  " .. target )
  local http = require "resty.http"
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
      path = target,
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
--   if not res then
--     return requestError(
--       ngx.HTTP_SERVICE_UNAVAILABLE,
--       'HTTP service unavailable',
--       'connection failure')
--   end

  if res.has_body then
    body, err = res:read_body()
    if not body then
      return requestError(
        ngx.HTTP_SERVICE_UNAVAILABLE,
        'HTTP service unavailable',
        'connection failure')
    end
    ngx.log(ngx.INFO, "status: ", res.status)
    ngx.log(ngx.INFO,"reason: ", res.reason)
    ngx.log(ngx.INFO,"body: ", body)
    ngx.status = ngx.HTTP_OK
    -- local args  = cjson.decode(ngx.req.get_body_data())
    ngx.print(body)
    ngx.exit( ngx.HTTP_OK )
  end
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

function sendWebMention( endpoint, source, target )
  ngx.log(ngx.INFO, ' Send Web Mention ' )
  ngx.log(ngx.INFO, '------------------' )
  local contentType = 'application/x-www-form-urlencoded'
  local formBody = 'source=' .. source .. '&target=' .. target
  return util.post( endpoint, contentType, formBody)
end

function putXML2( collection, props )
  ngx.log(ngx.INFO, 'do putXML' )
  local rootName  = 'upload'
  local http = require "resty.http"
  local authorization = cfg.auth
  local contentType = 'application/xml'
  local domain   = cfg.domain 
  local resource =  props.id
  --local kindOfPost = xml.find(data, 'entry').kind
  local dataPath = "/exist/rest/db/data/" .. domain  .. '/docs'
  -- store without extension
  local putPath  = dataPath .. '/' .. collection .. '/' .. resource
  local properties = {}
  for property, item in pairs(props) do
    local xmlNode =  '<' .. property .. '>' .. item .. '</' .. property .. '>'
    table.insert(properties,xmlNode)
    -- ngx.log(ngx.INFO, xmlNode)
  end

  local xmlDoc=  '<' .. rootName .. '>' .. table.concat(properties) .. '</' .. rootName .. '>'
  ngx.log(ngx.INFO, xmlDoc)


  local httpc = http.new()
  local ok, err = httpc:connect(cfg.host, cfg.port)
  if not ok then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end

  local response, err = httpc:request({
      version = 1.1,
      method = "PUT",
      path = putPath,
      headers = {
        ["Authorization"] = authorization,
        ["Content-Type"] = contentType
      },
      body = xmlDoc,
      ssl_verify = false
    })

  if not response then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'no response' )
  end
  ngx.log(ngx.INFO, "status: ", response.status)
  ngx.log(ngx.INFO,"reason: ", response.reason)
  return response.reason
end

function putMedia( props )
  local http = require "resty.http"
  local authorization = cfg.auth 
  local domain        = cfg.domain
  -- ngx.say( contentType )
  local dataPath = "/exist/rest/db/data/" .. domain
  local colPath  = "media"
  local putPath  = dataPath .. '/' .. colPath .. '/' .. props.name
  local httpc = http.new()
  local ok, err = httpc:connect(cfg.host, cfg.port)
  if not ok then 
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end

  local response, err = httpc:request({
      version = 1.1,
      method = "PUT",
      path = putPath,
      headers = {
        ["Authorization"] = authorization,
        ["Content-Type"] = props.mime
      },
      body =  read( props.temp ) ,
      ssl_verify = false
    })
  if not response then
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'request failure')
  end
  if response.has_body then
    body, err = response:read_body()
    if not body then
      ngx.say("failed to read body: ", err)
      return
    end
  end

  ngx.log(ngx.INFO, "status: ", response.status)
  ngx.log(ngx.INFO,"reason: ", response.reason)
  return response.reason
end 

--[[
function xprocessMultPartForm()
    --  grantmacken.parser is lua-resty-multipart-parser - Simple multipart data parser for OpenResty/Lua
  --  from agentzha TODO! check if avaible on OPM
  --  @see https://github.com/agentzh/lua-resty-multipart-parser
  local parser = require "grantmacken.parser" 
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
    local sID = require('grantmacken.postID').getID( 'm' )
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
    local reason =  require('grantmacken.eXist').putMedia( part_body,  mediaFileName , mimeType )
    if reason == 'Created' then
      -- NOTE: return binary source as location
      ngx.header.location = properties['src']
      -- Note create a doc for the 'shoebox
      local reason2 =  require('grantmacken.eXist').putXML( 'uploads',  data )
      if reason2 == 'Created' then
        ngx.say(require('xml').dump(data))
        ngx.exit(ngx.HTTP_CREATED)
      end
    end
  end
end

--]]
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
