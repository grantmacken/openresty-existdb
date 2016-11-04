local _M = {}
--[[
curl https://gmack.nz/info
--]]


function _M.processRequest()
  ngx.say('INFO')
  ngx.say(package.path)
end


return _M
