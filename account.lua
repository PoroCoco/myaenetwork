local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")
local shell = require("shell")

local urlAccount = "http://myaenetwork.ovh/accountCreation"
local webIdPath = "/home/myaenetwork/webIdentification.txt"
local workDirectory = "/home/myaenetwork/"
local newDirectory = "/home/myaenetwork"

function lsh(value,shift)
	return (value*(2^shift)) % 256
end

-- shift right
function rsh(value,shift)
	return math.floor(value/2^shift) % 256
end

-- return single bit (for OR)
function bit(x,b)
	return (x % 2^b - x % 2^(b-1) > 0)
end

-- logic OR for number values
function lor(x,y)
	result = 0
	for p=1,8 do result = result + (((bit(x,p) or bit(y,p)) == true) and 2^(p-1) or 0) end
	return result
end

-- encryption table
local base64chars = {[0]='A',[1]='B',[2]='C',[3]='D',[4]='E',[5]='F',[6]='G',[7]='H',[8]='I',[9]='J',[10]='K',[11]='L',[12]='M',[13]='N',[14]='O',[15]='P',[16]='Q',[17]='R',[18]='S',[19]='T',[20]='U',[21]='V',[22]='W',[23]='X',[24]='Y',[25]='Z',[26]='a',[27]='b',[28]='c',[29]='d',[30]='e',[31]='f',[32]='g',[33]='h',[34]='i',[35]='j',[36]='k',[37]='l',[38]='m',[39]='n',[40]='o',[41]='p',[42]='q',[43]='r',[44]='s',[45]='t',[46]='u',[47]='v',[48]='w',[49]='x',[50]='y',[51]='z',[52]='0',[53]='1',[54]='2',[55]='3',[56]='4',[57]='5',[58]='6',[59]='7',[60]='8',[61]='9',[62]='-',[63]='_'}

-- function encode
-- encodes input string to base64.
function encode(data)
	local bytes = {}
	local result = ""
	for spos=0,string.len(data)-1,3 do
		for byte=1,3 do bytes[byte] = string.byte(string.sub(data,(spos+byte))) or 0 end
		result = string.format('%s%s%s%s%s',result,base64chars[rsh(bytes[1],2)],base64chars[lor(lsh((bytes[1] % 4),4), rsh(bytes[2],4))] or "=",((#data-spos) > 1) and base64chars[lor(lsh(bytes[2] % 16,2), rsh(bytes[3],6))] or "=",((#data-spos) > 2) and base64chars[(bytes[3] % 64)] or "=")
	end
	return result
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
    if internet.request(urlAccount, encode(accountData))() == "Account accepted" then
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