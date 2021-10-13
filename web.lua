local computer = require("computer")
local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")
local shell = require("shell")

local me

if component.isAvailable("me_controller") then
    me = component.me_controller
elseif component.isAvailable("me_interface") then
    me = component.me_interface
else
    print("You need to connect the adapter to either a me controller or a me interface")
    os.exit()
end

local version = "0.12"
local working = true
local webIdPath = "home/myaenetwork/webIdentification.txt"
local workingDirectory = "home/myaenetwork/"

local urlSendItemData = "http://myaenetwork.ovh/inputItemData"
local pingUrl = "http://myaenetwork.ovh/toPing"
local urlSendCraftingStatus = "http://myaenetwork.ovh/inputCraftingStatus"

local issuedCraftingRequest = {}
local maxPing = 1000
local followedPing = 0
local serverTimeoutReconnect = 300

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

function isConfigCorrect(rid, rusername,rpassword)
    if rid == nil or rusername == nil or rpassword == nil then
        return false
    end
    if rid == "" or rusername == "" or rpassword == "" then
        return false
    else
        return true
    end
end

function getItemDataString()
    local string = ""
    local isModpackGTNH, storedItems = pcall(me.allItems) --tries the allItems method only available on the GTNH modpack. 
    if isModpackGTNH then
        for item in storedItems do
            if type(item) == 'table' then
                string = string .. item['label'] .. "~" .. item["size"] .. "~".. tostring(item["isCraftable"])..";"
            end
        end
        return string
    else
        for k,v in pairs(me.getItemsInNetwork()) do
            if type(v) == 'table' then
                string = string .. v['label'] .. "~" .. v["size"] .. "~".. tostring(v["isCraftable"])..";"
            end
        end
        return string
    end
end

function requestItem(name, number)
    local craftables = me.getCraftables()
    for k,v in pairs(craftables) do
        if type(v) == 'table' then
            item = v.getItemStack()
            if item['label'] == name then
                local craft = v.request(number)
                return craft
            end
        end
    end
    return "existe pas"
end

function craftingStatusDataToString(table)
    local craftingStrig = ""
    for k,v in pairs(table) do
        craftingStrig = craftingStrig .. v[1] ..";"..v[2]..";"
        local itemStatus = tostring(v[3].isDone())
        if itemStatus == "true" then
            itemStatus = "Done"
        elseif itemStatus == "false" then
            itemStatus = "Crafting"
        end
        if v[3].isCanceled() then
            itemStatus = "Canceled"
        end
        craftingStrig = craftingStrig .. itemStatus .."}"
    end
    return craftingStrig
end

function printCraftingStatus(table)
    for k,v in pairs(table) do
        io.write(v[1])
        io.write("   ")
        io.write(v[2])
        io.write("   ")
        local itemStatus = tostring(v[3].isDone())
        if itemStatus == "true" then
            itemStatus = "Done"
        elseif itemStatus == "false" then
            itemStatus = "Crafting"
        end
        if v[3].isCanceled() then
            itemStatus = "Canceled -> Missing ressources"
        end
        io.write(itemStatus)
        io.write("\n")
    end
end

function processPing(string)
    local t ={}
    for i=1,#string do
        t[i] = string:sub(i, i)
    end
    local itemRequested = ""
    local numberRequested = ""
    local code = ""
    local indexStopped = 1
    for i=1,#string do
        if string:sub(i, i) == ";" then
            indexStopped = i
            break
        end
        code = code .. string:sub(i, i)
    end
    for i=indexStopped+1,#string do
        if string:sub(i, i) == ";" then
            indexStopped = i
            break
        end
        itemRequested = itemRequested..string:sub(i, i)
    end
    for i=indexStopped+1,#string do
        if string:sub(i, i) == ";" then
            indexStopped = i
            break
        end
        numberRequested = numberRequested..string:sub(i, i)
    end

    -- print(code)
    -- print(itemRequested)
    -- print(numberRequested)
    tab = {code,itemRequested,numberRequested}
    return tab
end

function getStringCpus()
    local string = ""
    for k,v in pairs(me.getCpus()) do
        if type(v) == 'table' then
            string = string .. v['name'] .. "~" .. tostring(v["storage"]) .. "~".. tostring(v["coprocessors"]).."~".. tostring(v["busy"])..";"
        end
    end
    return string
end

function webRequest(url,string)
    local isServerOnline, result = pcall(internet.request(url,string))
    if not isServerOnline then
        print("Couldn't connect. The Web server is likely offline. Retrying connection in "..serverTimeoutReconnect.." seconds.")
        os.sleep(serverTimeoutReconnect)
        return false
    else
        return result
    end
end

function updateProgram()
    print("You are using an outdated version !")
    print("Do you want to update ? Yes/No")
    local acceptedUpdate = io.read()
    if acceptedUpdate == "Yes" or acceptedUpdate == "yes" then
        os.execute("myaenetwork/MaenUpdater.lua")
    else
        print("You didn't accept the update. You cannot use the program with an outdated version")
        os.sleep(5)
        computer.shutdown(true)
	end
end

if filesystem.exists(webIdPath) then
    shell.setWorkingDirectory(workingDirectory)
    local f = io.open("webIdentification.txt","r")
    local rid = f:read('*l')
    local rusername = f:read('*l')
    local rpassword = f:read('*l')
    local computer_id
    if rid ~= nil then
        computer_id = string.sub(rid,6) 
    end
    f:close()
    shell.setWorkingDirectory("/home/")

    if isConfigCorrect(rid,rusername,rpassword) then
        print("Started")
        while working do
            ::restart::
            followedPing = followedPing + 1 
            local pingResult = webRequest(pingUrl,version..";"..tostring(computer_id))
            if not pingResult then goto restart end
            pingResult = processPing(pingResult)
            local needUpdate = pingResult[1]
            local itemRequested = pingResult[2]
            local numberRequested = pingResult[3]

            if needUpdate == "Outdated" then
                updateProgram()
            end

            if needUpdate == "True" then
                followedPing = 0
                print("Server is requesting data")
                dataResult = webRequest(urlSendItemData,encode(getItemDataString().."|"..tostring(me.getAvgPowerUsage())..";"..tostring(me.getMaxStoredPower())..";"..tostring(me.getStoredPower()).."|"..getStringCpus()..";"..tostring(computer_id)))
                if not pingResult then goto restart end
                if dataResult == "OK" then
                    print("Data sent")
                end
                if itemRequested ~= "EMPTY" then
                    local subTable ={}
                    subTable[1] = itemRequested
                    subTable[2] = numberRequested
                    subTable[3] = requestItem(itemRequested,tonumber(numberRequested))
                    if subTable[3] == 'existe pas' then
                        print("requested item doesn't exist in the craftables")
                        break
                    end
                    issuedCraftingRequest[#issuedCraftingRequest+1] = subTable
                    webCraftingResult = webRequest(urlSendCraftingStatus, encode(craftingStatusDataToString(issuedCraftingRequest)..";"..tostring(computer_id)))
                    if not webCraftingResult then goto restart end
                    if webCraftingResult == "OK" then
                        print(subTable[1],subTable[2])
                        print("Crafting status sent")
                    else
                        print("Couldn't send crafting status")
                    end
                else 
                    webCraftingResult = webRequest(urlSendCraftingStatus, encode(craftingStatusDataToString(issuedCraftingRequest)..";"..tostring(computer_id)))
                    if not webCraftingResult then goto restart end
                    -- print("Crafing status updated")
                end
            end
            if #issuedCraftingRequest > 30 then
                table.remove(issuedCraftingRequest,1)
            end
            os.sleep(1)
            if followedPing >= maxPing then
                os.sleep(10)
            end
        end
    else
        print("No account created or account invalid.")
        print("Launch the 'account' file to create your account.")
    end
else
    print("No account created or account invalid.")
    print("Launch the 'account' file to create your account.")
end