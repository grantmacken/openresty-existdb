
local _M = {}

function _M.tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function contains(tab, val)
  for index, value in ipairs (tab) do
    if value == val then
      return true
    end
  end
  return false
end

function _M.requestError( status, msg, description )
  ngx.status = status
  ngx.header.content_type = 'application/json'
  local json = cjson.encode({
      error  = msg,
      error_description = description
    })
  ngx.print(json)
  ngx.exit(status)
end

function _M.acceptMethods( methods )
  -- ngx.say( 'the methods this endpoint can handle' )
  local method = ngx.req.get_method()
  if not contains( methods, method )  then
    return _M.requestError(
      ngx.HTTP_METHOD_NOT_IMPLEMENTED,
      method .. ' method not implemented',
      'endpoint does not accept' .. method .. 'methods')
  end
 return method
end

function _M.acceptContentTypes( contentTypes )
  --ngx.say("the content types this endpoint can handle")
  local contentType = ngx.var.http_content_type
  if not contentType then
    local msg = 'should have a content type'
    return _M.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted ',
      msg )
  end
  local from, to, err = ngx.re.find(contentType ,"(multipart/form-data|application/x-www-form-urlencoded|multipart/form-data)")
  if from then
    contentType =  string.sub( contentType, from, to )
  end
  if not contains( contentTypes, contentType )  then
    local msg = 'endpoint does not accept' .. contentType
    return _M.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted ',
      msg )
  end
  return contentType
end

function _M.acceptFormArgs( args , acceptArgs )
  for key, value in pairs( args ) do
    ngx.log(ngx.INFO, key )
    if not contains( acceptArgs, key )  then
      return _M.requestError(
        ngx.HTTP_NOT_ACCEPTABLE,
        'not accepted',
        'endpoint only does not accept ' .. key  )
    end
  end
 return true
end

function _M.extractID( url )
  -- short urls https://gmack.nz/xxxxx
  local sID, err = require("ngx.re").split(url, "([nar]{1}[0-9A-HJ-NP-Z_a-km-z]{4})")[2]
  if err then
    local msg = 'could not extract id from URL'
    return _M.requestError( ngx.HTTP_BAD_REQUEST,'bad request', msg)
  end
  return sID
end
return _M
