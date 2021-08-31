local shell = require("shell")
local filesystem = require("filesystem")
local computer = require("computer")
local component = require("component")

filesystem.makeDirectory("home/myaenetwork")
shell.setWorkingDirectory("home/myaenetwork/")

print("downloading")
shell.execute("wget https://raw.githubusercontent.com/myaenetwork/blob/main/account.lua")
shell.execute("wget https://raw.githubusercontent.com/myaenetwork/blob/main/web.lua")
shell.setWorkingDirectory("home/")
filesystem.remove("autoInstall.lua")
print("done")