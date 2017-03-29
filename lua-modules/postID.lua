
local _M = {}

--[[

DESCRIPTION:  create a short id unique to the db
              combined with a registered domain you get a short URL 
              that is a URL based Unique ID that is global in scope
              e.g. https://gmack.nz/n4Xh1

              The ID is date-encoded. We can make a claim that
              the owner of the domain 'at this date' generated the ID

 5 chars long

   [a-z]{1}  shortKindOfPost n = note
   [\w]{3}   short date base60 encoded 
   [\w]{1}   the base60 encoded incremented number of entries for the day
 = total of 5 chars

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
--


function encodeDate()
  local shortDate = os.date("%y") .. os.date("%j")
  local integer = tonumber( shortDate )
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

function _M.getID(k)
  --  ngx.say( 'get Post ID' )
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
  -- TODO! comment out test
   ngx.log(ngx.INFO,  'comment out after test' )
   slugDict:replace("count", 1)
   ngx.log(ngx.INFO,  'COUNT: ' .. slugDict:get("count") )
  -- ngx.say(slugDict:get("count"))
  -- ngx.say(slugDict:get("today"))
  return k .. slugDict:get("today") .. b60Encode(slugDict:get("count"))
end

return _M
