local computer = require("computer")
local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")
local shell = require("shell")

local me = component.me_controller

local version = "0.11"
local working = true
local webIdPath = "home/myaenetwork/webIdentification.txt"
local workingDirectory = "home/myaenetwork/"

local urlSendItemData = "http://127.0.0.1:5000/inputItemData"
local pingUrl = "http://127.0.0.1:5000/toPing"
local urlSendCraftingStatus = "http://127.0.0.1:5000/inputCraftingStatus"

local issuedCraftingRequest = {}
local maxPing = 1000
local followedPing = 0
local serverTimeoutReconnect = 300

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
    for k,v in pairs(me.getItemsInNetwork()) do
        if type(v) == 'table' then
            string = string .. v['label'] .. "~" .. v["size"] .. "~".. tostring(v["isCraftable"])..";"
        end
    end
    return string
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
        os.execute("MaenUpdater")
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
    local computer_id = string.sub(rid,6) 
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
                dataResult = webRequest(urlSendItemData,getItemDataString().."|"..tostring(me.getAvgPowerUsage())..";"..tostring(me.getMaxStoredPower())..";"..tostring(me.getStoredPower()).."|"..getStringCpus()..";"..tostring(computer_id) )
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
                    webCraftingResult = webRequest(urlSendCraftingStatus, craftingStatusDataToString(issuedCraftingRequest)..";"..tostring(computer_id))
                    if not webCraftingResult then goto restart end
                    if webCraftingResult == "OK" then
                        print(subTable[1],subTable[2])
                        print("Crafting status sent")
                    else
                        print("Couldn't send crafting status")
                    end
                else 
                    webCraftingResult = webRequest(urlSendCraftingStatus, craftingStatusDataToString(issuedCraftingRequest)..";"..tostring(computer_id))
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