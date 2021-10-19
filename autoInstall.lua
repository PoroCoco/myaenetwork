local shell = require("shell")
local filesystem = require("filesystem")
local computer = require("computer")

if not filesystem.exists("/home/myaenetwork") then

    filesystem.makeDirectory("/home/myaenetwork")
    shell.setWorkingDirectory("/home/myaenetwork/")

    print("Downloading")
    shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/account.lua")
    shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/web.lua")
    shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/MaenUpdater.lua")
    shell.setWorkingDirectory("/home/")
    filesystem.remove("home/autoInstall.lua")
    print("Done")
    print("Switching computer architecture to Lua 5.3")
    computer.setArchitecture("Lua 5.3")

else
    print("Already installed")
end
