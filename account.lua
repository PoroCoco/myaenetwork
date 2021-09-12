local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")
local shell = require("shell")

local urlAccount = "http://127.0.0.1:5000/accountCreation"
local webIdPath = "/home/myaenetwork/webIdentification.txt"
local workDirectory = "/home/myaenetwork/"
local newDirectory = "/home/myaenetwork"

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
    local id = math.floor(math.random(1000000))
    local username = io.read()
    while username == "" or string.match(username, ";") do
        print("Your username cannot be empty or contain ';'")
        print("Choose your account username.")
        username = io.read()
    end
    print("Your username is ".. username)
    print()
    print("Choose your account password.")
    print("DO NOT USE A SENSITIVE PASSWORD, THEY ARE NOT ENCRYPTED")
    print("I RECOMMAND YOU TO USE A PIN/SMALL PASSWORD")
    local password = io.read()
    while password == ""  or string.match(password, ";") do
        print("Your password cannot be empty or contain ';'")
        print("Choose your account password.")
        password = io.read()
    end
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
    f:write("username = "..username, "\n")
    f:write("password = "..password)
    f:close()
    print("Configuration is done !")
end

function accountToServer(id, username, password)
    local accountData = tostring(id)..";"..username..";"..password
    shell.setWorkingDirectory("/home/") -- if the server is down, internet.request will give an error so before trying it's going back to the basic dir 
    if internet.request(urlAccount, accountData)() == "Account accepted" then
        shell.setWorkingDirectory(workDirectory)
        return true
    else 
        shell.setWorkingDirectory(workDirectory)
        return false
    end
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
                print("Your account "..rpassword)
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