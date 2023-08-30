local component = require("component")
local internet = component.internet
local filesystem = require("filesystem")
local shell = require("shell")
package.loaded.poroNet = nil
local poroNet = require("myaenetwork/poroNet")


local server_ip = "myaenetwork.ovh"
local server_port = 9876
local webIdPath = "/home/myaenetwork/webIdentification.txt"
local workDirectory = "/home/myaenetwork/"
local newDirectory = "/home/myaenetwork"


-- Uuid for account creation
local random = math.random --somehow calling randomseed with time+clock makes it no longer random ?
function uuid()
   local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
   return string.gsub(template, '[xy]', function (c)
      local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
      return string.format('%x', v)
   end)
end


function isConfigCorrect(rid, rusername,rpassword) --checks if each line of the identification file as the right data 
    if rid == nil or rusername == nil or rpassword == nil then
        return false
    end
    if rid == "" or rusername == "" or rpassword == "" then
        return false
    else
        return true
    end
end

function createAccount()
    print("Let's configure your account")
    print("The account is linked to the computer, you will use the account username and password to connect on the web page")
    print("Choose your account username")
    local id = uuid()
    local username = io.read()
    while username == "" or string.match(username, ";") or #username > 128 do
        print("Your username cannot be empty, longer than 128 characters or contain ';'")
        print("Choose your account username.")
        username = io.read()
    end
    print("Your username is ".. username)
    print()
    print("Choose your account password.")
    print("DO NOT USE A SENSITIVE PASSWORD, THEY ARE NOT ENCRYPTED")
    print("I RECOMMAND YOU TO USE A PIN/SMALL PASSWORD")
    local password = io.read()
    while password == ""  or string.match(password, ";") or #password > 128 do
        print("Your password cannot be empty, longer than 128 characters or contain ';'")
        print("Choose your account password.")
        password = io.read()
    end
    print("Waiting for server ...")
    if accountToServer(id,username,password) then 
        print("Account creation accepted by the server")
    else
        print("Account creation denied by the server")
        print("Server might be offline or account already registered")
        print("Please try the account creation one more time WITH A DIFFERENT USERNAME. Otherwise contact PoroCoco#4636 on Discord")
        return
    end
    local f = io.open(webIdPath,"w") -- writes the infos into the identification file
    f:write("id = "..tostring(id), "\n")
    f:write("username = "..tostring(username), "\n")
    f:write("password = "..tostring(password))
    f:close()
    print("Configuration is done !")
end

function accountToServer(id, username, password)
    local socket = internet.connect(server_ip, server_port)
    if socket then
        -- Wait for the connection to be established
        while not socket.finishConnect() do
            os.sleep(0.25)
        end
        print("Connected to server")
        socket.write(poroNet.packet_account(username, id, password))
        os.sleep(1)
        --getting the acknowledgement
        local data = socket.read(6)
        if (data ~= nil and #data > 0) then
            local ack = poroNet.get_header_flag(data)
            return ack == poroNet.flags.account.SUCCESS
        else 
            print("No response from the server")
            return false
        end
        return false
    end
    return false
end

if component.isAvailable("internet") then
    filesystem.makeDirectory(newDirectory)
    shell.setWorkingDirectory(workDirectory)
    if filesystem.exists(webIdPath) then --tries to read the identification file, if it cannot start an account creation
        local f = io.open(webIdPath,"r")
        local rid = f:read('*l')
        local rusername = f:read('*l')
        local rpassword = f:read('*l')
        if isConfigCorrect(rid,rusername,rpassword) then
            print("Computer is already configured")
            print("Your account "..rusername)
            print("Show account password ? Yes/No")
            if io.read() == "Yes" then
                print("Your account password is "..rpassword)
            end
        else
            print("config file isn't correct. Remaking one")
            createAccount()
        end
        f:close()
        shell.setWorkingDirectory("/home/")
    else 
        createAccount()
        shell.setWorkingDirectory("/home/")
    end
else
    print("Please insert the Internet Card into the computer")
end