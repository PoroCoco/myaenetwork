local computer = require("computer")
local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")
local shell = require("shell")


function architectureCheck()
    if computer.getArchitecture() ~= "Lua 5.3" then
        print("Your computer isn't running on the requiered architecture")
        print("The computer will change from Lua 5.2 to Lua 5.3. Please restart the program after the reboot :)")
        for i=1,5 do
            print(6-i)
            os.sleep(1)
        end
        computer.setArchitecture("Lua 5.3")
        computer.shutdown(true)
    end
end

architectureCheck()

os.execute("myaenetwork/accountAux.lua")