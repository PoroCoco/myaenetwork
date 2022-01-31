local shell = require("shell")
local filesystem = require("filesystem")
local computer = require("computer")

shell.setWorkingDirectory("/home/myaenetwork/")
shell.execute("rm *.lua")

print("Updating")
shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/account.lua")
shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/web.lua")
shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/MaenUpdater.lua")
shell.execute("wget https://raw.githubusercontent.com/rxi/json.lua/master/json.lua")

shell.setWorkingDirectory("/home/")
print("Rebooting")
computer.shutdown(true)