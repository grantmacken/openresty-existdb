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
auth = 'Basic ' .. os.getenv("EXIST_AUTH"),
domain = ngx.var.site 
}
--
--UTILITY TODO move to utility.lua
local function contains(tab, val)
  for index, value in ipairs (tab) do
    if value == val then
      return true
    end
  end
  return false
end

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

local function acceptMethods(methods)
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

function _M.processRequest()
  ngx.log(ngx.INFO, "Process Request" )
  ngx.log(ngx.INFO, "" )
  local method =  acceptMethods({"POST","GET"})
  ngx.log(ngx.INFO, "Accepted Method [ " .. method  .. ' ]')
  if method == "POST" then
     processPost()
  else
     processGet()
  end
end

function processGet()
  ngx.log(ngx.INFO, "Process GET query to eXist endpoint")
  ngx.log(ngx.INFO, ngx.var.uri)
  local response = {}
  local msg = ''
  local args = ngx.req.get_uri_args()
  if not args[1] then
    -- TODO!
    ngx.log(ngx.INFO, "Look for path")
    msg =  "No arguments in URL"
    ngx.log(ngx.WARN, msg)
    requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
  end
    -- TODO!
    ngx.log(ngx.INFO, "Look for path")
    for key, val in pairs(args) do
      if type(val) == "table" then
        ngx.say(key, ": ", table.concat(val, ", "))
      else
        ngx.say(key, ": ", val)
      end
    end
    
end

function processPost()
  ngx.log(ngx.INFO, "Process the content-types this endpoint can handle")
  local contentType = acceptContentTypes({
      'application/xml',
      'application/json',
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    })
  ngx.log(ngx.INFO, "Accepted Content Type [ " .. contentType  .. ' ]')
  --  ngx.say( contentType )
  if contentType  == 'application/x-www-form-urlencoded' then
    --processPostArgs()
  elseif contentType  == 'multipart/form-data' then
    -- ngx.say( contentType )
    --processMultPartForm()
  elseif contentType  == 'application/json' then
    -- processJsonBody()
  end
end


 -- +++++++++++++++++++++++++++++++++++++++++++++++++++
 -- generic exist endpoint for talking to eXistdb 

 -- function _M.processRequest()
 --   local msg = ''
 --   local method = ngx.req.get_method()
 --   local contentType =  ngx.req.get_headers()["Content-Type"]
 --   ngx.log(ngx.INFO, "Method: " .. method)
 --   if contentType ~= nil then
 --     msg = "content negotiation for: " .. contentType
 --     ngx.log(ngx.INFO, msg)
 --   else
 --     ngx.status = ngx.HTTP_BAD_REQUEST
 --     ngx.log(ngx.INFO, 'No content type ... exiting')
 --     ngx.eof()
 --   end
 --    ngx.say( method )

    -- local h = ngx.req.get_headers()
 -- for k, v in pairs(h) do
    --  ngx.log(ngx.INFO,  k ..  ' : ' .. v )
   -- end
   -- ngx.log(ngx.INFO, "Content-Type" .. contentType)
   -- ngx.say( method )
   -- ngx.say( contentType )
   -- ngx.say( ngx.var.resources )
   -- ngx.say( ngx.var.media)
   -- ngx.req.read_body()
   -- local data = ngx.req.get_body_data()
   -- local http = require "resty.http"
   -- local authorization = cfg.auth 
   -- local domain        = ngx.var.site
   -- -- ngx.say( ngx.var.uri )
   -- -- ngx.say( ngx.var.request_uri )
   -- local restPath  = "/exist/rest/db/apps/" .. domain 
   -- -- ngx.say( docPath )
   -- local httpc = http.new()
   -- -- local scheme, host, port, path, query? = unpack(httpc:parse_uri(uri, false))
   -- local ok, err = httpc:connect(cfg.host, cfg.port)
   -- if not ok then 
   --   return requestError(
   --     ngx.HTTP_SERVICE_UNAVAILABLE,
   --     'HTTP service unavailable',
   --     'connection failure')
   -- end
   -- httpc:set_timeout(2000)
   -- httpc:proxy_response( httpc:request({
   --       version = 1.1,
   --       method = "POST",
   --       path = restPath,
   --       headers = {
   --         ["Content-Type"] = "application/xml",
   --         ["Authorization"] = authorization 
   --       },
   --       body =  data,
   --       ssl_verify = false
   --   }))
   -- httpc:set_keepalive()
 -- end

return _M
