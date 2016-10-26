 local _M = {}

local kindsOfPosts = {
 note = true,
 article = true
}



local shortKindOfPost = {
 note = 'n'
}



function _M.getShortKindOfPost(kind)
  return shortKindOfPost[kind]
end




 local data = {
     dog = 3,
     cat = 4,
     pig = 5,
 }




 function _M.get_age(name)
     return data[name]
 end

 return _M
