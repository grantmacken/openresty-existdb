local _M = {}

local cfg = {
  port = 8080,
  host = '127.0.0.1',
  auth = 'Basic ' .. os.getenv("EXIST_AUTH"),
  domain = ngx.var.domain
}

function _M.get( item )
  return cfg[item]
end



return _M
