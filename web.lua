local computer = require("computer")
local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")
local shell = require("shell")
local json = require("json")

local webIdPath = "home/myaenetwork/webIdentification.txt"
local workingDirectory = "home/myaenetwork/"

local urlSendItemData = "http://myaenetwork.ovh/inputItemData"
local pingUrl = "http://myaenetwork.ovh/toPing"
local urlSendCraftingStatus = "http://myaenetwork.ovh/inputCraftingStatus"

local progVersion = "1.0"

local issuedCraftingRequest = {}
local maxPing = 1000
local followedPing = 0
local serverTimeoutReconnect = 300

local computer_id 
local me
local data = component.data

function findME()
    if component.isAvailable("me_controller") then
        me = component.me_controller
    elseif component.isAvailable("me_interface") then
        me = component.me_interface
    else
        print("You need to connect the adapter to either a me controller or a me interface")
        os.exit()
    end
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

function checkConfig()
    if not filesystem.exists(webIdPath) then
        print("No account created or account invalid.")
        print("Launch the 'account' file to create your account.")
    end


    shell.setWorkingDirectory(workingDirectory)
    local f = io.open("webIdentification.txt","r")
    local rid = f:read('*l')
    local rusername = f:read('*l')
    local rpassword = f:read('*l')

    if not isConfigCorrect(rid,rusername,rpassword) then
        print("Invalid config file !")
        f:close()
        os.exit()
    end

    computer_id = string.sub(rid,6) 

    f:close()
    shell.setWorkingDirectory("/home/")
end

function startupCheck()
    findME()
    local components = {"data", "internet"}

    for _,compo in pairs(components) do
        if not component.isAvailable(compo) then print("You are missing the "..compo.." component !") os.exit() end
    end

    checkConfig()
end



function webRequest(url,jsonString)
    local jsonString = data.encode64(jsonString)
    local isServerOnline, result = pcall(internet.request(url,jsonString))
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

function pingWebServer()
    local argTable = {["progVersion"] = progVersion,["computer_id"] = computer_id}

    return webRequest(pingUrl, json.encode(argTable))
end

function processPing(jsonString)
    local tableRes = json.decode(jsonString)
    local craftRequest = json.decode(tableRes["craftingRequest"])
    return tableRes.updateRequest,craftRequest.itemName, craftRequest.itemNumber 
end

function getItemsTable()
    local res = {}
    local isModpackGTNH, storedItems = pcall(me.allItems) --tries the allItems method only available on the GTNH modpack. 
    if isModpackGTNH then
        for item in storedItems do
            if type(item) == 'table' then
                res[item['label']] = {["size"] = item["size"], ["isCraftable"] = tostring(item["isCraftable"])}
            end
        end
        return res
    else
        for k,v in pairs(me.getItemsInNetwork()) do
            if type(v) == 'table' then
                res[v['label']] = {["size"] = v["size"], ["isCraftable"] = tostring(v["isCraftable"])}
            end
        end
        return res
    end

end

function getNetworkEnergy()
    local res = {}
    
    res["avgPowerUsage"] = me.getAvgPowerUsage()
    res["maxStoredPower"] = me.getMaxStoredPower()
    res["storedPower"] = me.getStoredPower()

    return res
end

function getNetworkCpus()
    local res = {}
    for index, cpu in pairs(me.getCpus()) do
        if type(cpu) == 'table' then
            res[index] = cpu
            if res[index]["name"] == "" then
                res[index]["name"] = tostring(index)
            end
        end
    end

    return res
end

function getFullNetworkTable()
    local res = {}

    res["items"] = getItemsTable()
    res["energy"] = getNetworkEnergy()
    res["cpus"] = getNetworkCpus() 
    res["computer_id"] = computer_id

    return res
end

function createCraftingStatusTable(tableIssued)
    local craftingTable = {}
    craftingTable["crafts"] = {}
    for k,v in pairs(tableIssued) do
        craftingTable["crafts"][k] = {}
        craftingTable["crafts"][k][1] = v[1]
        craftingTable["crafts"][k][2] = v[2]

        if v[3].isDone() then
            craftingTable["crafts"][k][3] = "Done"
        else 
            craftingTable["crafts"][k][3] = "Crafting"
        end
        if v[3].isCanceled() then
            craftingTable["crafts"][k][3] = "Canceled"
        end
    end
    craftingTable["computer_id"] = computer_id
    return craftingTable
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
    return "failed"
end


startupCheck()
print("Program started")
while true do
    ::restart::
    os.sleep(1)
    if #issuedCraftingRequest > 30 then
        table.remove(issuedCraftingRequest,1)
    end


    local pingResult = pingWebServer()
    if not pingResult then goto restart end
    if pingResult == "Outdated" then print("update pls") os.exit() updateProgram() end

    local needUpdate, itemRequested, numberRequested = processPing(pingResult)

    followedPing = followedPing + 1 
    if followedPing >= maxPing then
        os.sleep(3)
    end

    

    if needUpdate ~= true then goto restart end

    followedPing = 0
    print("Server is requesting data")

    local dataToSend = getFullNetworkTable()
    local serverResponse = webRequest(urlSendItemData, json.encode(dataToSend))

    if serverResponse == "OK" then
        print("Data sent")
    end

    if itemRequested ~= "EMPTY" then
        local subTable ={}
        subTable[1] = itemRequested
        subTable[2] = numberRequested
        subTable[3] = requestItem(itemRequested,tonumber(numberRequested))
        if subTable[3] == 'failed' then
            print("requested item doesn't exist in the craftables")
            goto restart
        end

        issuedCraftingRequest[#issuedCraftingRequest+1] = subTable
        local craftingStatusTable = createCraftingStatusTable(issuedCraftingRequest)
        local webCraftingResult = webRequest(urlSendCraftingStatus, json.encode(craftingStatusTable))
    
        if not webCraftingResult then goto restart end
        if webCraftingResult == "OK" then
            print(subTable[1],subTable[2])
            print("Crafting status sent")
        else
            print("Couldn't send crafting status")
        end
    else 
        local craftingStatusTable = createCraftingStatusTable(issuedCraftingRequest)
        local webCraftingResult = webRequest(urlSendCraftingStatus, json.encode(craftingStatusTable))
        if not webCraftingResult then goto restart end
    end
end