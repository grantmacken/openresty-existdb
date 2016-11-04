local _M = {}
--[[
curl https://gmack.nz/info
--]]


function _M.processRequest()
  ngx.say('INFO')
  ngx.say('----')
  ngx.say(package.path)
  ngx.say('-----------------------------------------------')
  ngx.say('Pre Built Packages :')
  ngx.say('--------------------')
  ngx.say('init-by-lua')
  ngx.say('cjson: ')
  local json = cjson.encode({
      message  = 'Hi'
    }) 
  ngx.say( json )
  ngx.say('ngx.ssl : ' .. type(require("ngx.ssl")))
  ngx.say('env vars')
  ngx.say('--------')
  ngx.say(os.getenv("EXIST_AUTH") )
  ngx.say(json)
  ngx.say('OPM Packages :')
  ngx.say('--------------')
  ngx.say('resty.http : ' .. type(require("resty.http")))
  ngx.say('')
  ngx.say('Luarocks Packages :')
  ngx.say('-------------------')
  ngx.say('net.url : ' .. type(require("net.url")))
  ngx.say('xml : ' .. type(require("xml")))
  --ngx.say(type(http)
  ngx.say('-------------------')
  ngx.say('My Modules')
  ngx.say('----------')
end


return _M
