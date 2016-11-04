
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
return _M
