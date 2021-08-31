local shell = require("shell")
local filesystem = require("filesystem")

filesystem.makeDirectory("/home/myaenetwork")
shell.setWorkingDirectory("/home/myaenetwork/")

print("downloading")
shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/account.lua")
shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/web.lua")
shell.setWorkingDirectory("/home/")
filesystem.remove("autoInstall.lua")
print("done")