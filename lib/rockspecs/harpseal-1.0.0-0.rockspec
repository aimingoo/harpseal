package = "harpseal"
version = "1.0.0-0"
source = {
  url = "https://github.com/aimingoo/harpseal/archive/v1.0.0.tar.gz",
  dir = "harpseal-1.0.0"
}
description = {
  summary = "harpseal - distribution task for lua",
  detailed = [[
    harpseal is implement of PEDT(Parallel Exchangeable Distribution Task) specifications in lua.
  ]],
  homepage = "https://github.com/aimingoo/harpseal",
  license = "Apache-2.0 <http://opensource.org/licenses/Apache-2.0>"
}
dependencies = {
  "lua >= 5.1",
  "copas >= 2.0.0-0",
  "luasocket >= 3.0",
}
build = {
  type = "builtin",
  modules = {
    ["harpseal"]  = "lib/harpseal.lua",
    ["harpseal.infra.taskhelper"]  = "infra/taskhelper.lua",
    ["harpseal.infra.httphelper"]  = "infra/httphelper.lua",
    ["harpseal.tools.taskloader"]  = "tools/taskloader.lua",
    ["tools.loadkit"]  = "loadkit/loadkit.lua",
    ["lib.Promise"]  = "lib/Promise.lua",
    ["lib.BASE64"]  = "lib/BASE64.lua",
    ["lib.MD5"]  = "lib/MD5.lua",
    ["lib.JSON"]  = "lib/JSON.lua",
  }
}
