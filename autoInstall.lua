local shell = require("shell")
local filesystem = require("filesystem")

if not filesystem.exists("/home/myaenetwork") then

    filesystem.makeDirectory("/home/myaenetwork")
    shell.setWorkingDirectory("/home/myaenetwork/")

    print("downloading")
    shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/account.lua")
    shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/web.lua")
    shell.execute("wget https://raw.githubusercontent.com/PoroCoco/myaenetwork/main/MaenUpdater.lua")
    shell.setWorkingDirectory("/home/")
    filesystem.remove("home/autoInstall.lua")
    print("done")

else
    print("Already installed")
end
