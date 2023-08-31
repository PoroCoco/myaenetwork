local component = require("component")
local event = require("event")
package.loaded.poroNet = nil
local poroNet = require("myaenetwork/poroNet")
local internet = component.internet


local server_ip = "myaenetwork.ovh"
local server_port = 9876

local current_version = "0.1"
local crafting_request_backlog_size = 30
local update_delay = 0.01
local user_config_file_path = "/home/myaenetwork/webIdentification.txt"

local issuedCraftingRequest = {}

-- Get the AE component
local me
if component.isAvailable("me_controller") then
    me = component.me_controller
elseif component.isAvailable("me_interface") then
    me = component.me_interface
else
    print("You need to connect the adapter to either a me controller or a me interface")
    os.exit()
end

function AE_get_items()
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

function AE_get_cpus()
    local string = ""
    for k,v in pairs(me.getCpus()) do
        if type(v) == 'table' then
            string = string .. v['name'] .. "~" .. tostring(v["storage"]) .. "~".. tostring(v["coprocessors"]).."~".. tostring(v["busy"])..";"
        end
    end
    return string
end

function AE_get_energy()
    return tostring(me.getAvgPowerUsage())..";"..tostring(me.getMaxStoredPower())..";"..tostring(me.getStoredPower())
end

function requestItem(name, number)
    number = tonumber(number)
    local craftables = me.getCraftables() -- Get the craftable items everytime, could only get it at the start of the program, downside is that if the user adds a new craft it won't get loaded until the program is rebooted
    for k,v in pairs(craftables) do
        if type(v) == 'table' then
            item = v.getItemStack()
            if item['label'] == name then
                local craft = v.request(number)
                return craft
            end
        end
    end
    return nil
end

function craftingStatusDataToString(table)
    local craftingStrig = ""
    for k,v in pairs(table) do
        craftingStrig = craftingStrig .. v[1] .."~"..v[2].."~"
        if v[3].isDone() then
            itemStatus = "Done"
        else 
            itemStatus = "Crafting"
        end
        if v[3].isCanceled() then
            itemStatus = "Canceled"
        end
        craftingStrig = craftingStrig .. itemStatus ..";"
    end
    return craftingStrig
end


function read_config_id()
    local config = io.open(user_config_file_path,"r")
    local id = config:read('*l')
    id = string.sub(id, 6)
    config:close()
    return id
end

function handle_craft_request(socket, packet_len)
    craft_data = socket.read(packet_len)
    -- print(craft_data)
    local subTable = {}
    local delimiter = string.find(craft_data, "~")
    requested_item = string.sub(craft_data, 1, delimiter - 1)
    requested_count = string.sub(craft_data, delimiter + 1)
    subTable[1] = requested_item
    subTable[2] = requested_count
    subTable[3] = requestItem(requested_item, requested_count)
    if (subTable[3] == nil) then
        print("Got asked for a craft that doesn't exist")
        return
    end
    -- print(subTable)
    issuedCraftingRequest[#issuedCraftingRequest+1] = subTable
    if #issuedCraftingRequest > crafting_request_backlog_size then
        table.remove(issuedCraftingRequest,1)
    end

end

function updateProgram()
    print("You are using an outdated version !")
    print("Do you want to update ? Yes/No")
    local acceptedUpdate = io.read()
    if acceptedUpdate == "Yes" or acceptedUpdate == "yes" then
        os.execute("myaenetwork/maenUpdater.lua")
    else
        print("You didn't accept the update. You cannot use the program with an outdated version")
        os.sleep(5)
        computer.shutdown(true)
	end
end


print("Starting connection")

-- Open a TCP socket connection
local socket = internet.connect(server_ip, server_port)

if socket then
    print("Connection started")

    -- Wait for the connection to be established
    while not socket.finishConnect() do
        os.sleep(1)
    end
    print("Connection established")

    -- Identify yourself so the server
    local id = read_config_id()
    socket.write(poroNet.packet_id(id, current_version))
    local _,_,_ = event.pull("internet_ready")
    local accepted = socket.read(1)
    if (accepted == "1") then
        updateProgram()
        exit()
    end

    while true do
      local data = socket.read(6)
      if (data ~= nil and #data > 0) then
        --  print("Received from server: ")
        --  poroNet.print_byte_array(data)
        --  print("packet type :", poroNet.get_header_type(data))
        --  print("packet len  :", poroNet.get_header_length(data))
        --  print("packet flag  :", poroNet.get_header_flag(data))
        local packet_type = poroNet.get_header_type(data)
        local packet_flags = poroNet.get_header_flag(data)
        if (packet_type == poroNet.packet_types.update) then
            print("Server asked for an update")
            local data = nil
            if (packet_flags == poroNet.flags.update.ITEM) then
                data = AE_get_items()
            elseif (packet_flags == poroNet.flags.update.ENERGY) then 
                data = AE_get_energy()
            elseif (packet_flags == poroNet.flags.update.CPUS) then 
                data = AE_get_cpus()
            elseif (packet_flags == poroNet.flags.update.CRAFT) then 
                data = craftingStatusDataToString(issuedCraftingRequest)
            elseif (packet_flags == poroNet.flags.update.ALL) then 
                data = AE_get_items().."|"..AE_get_energy().."|"..AE_get_cpus().."|"..craftingStatusDataToString(issuedCraftingRequest)
            else
                print("Unknown flag for the update packet. flag = ", packet_flags)
            end
            if (data ~= nil) then
                poroNet.sendall(socket, poroNet.create_header(poroNet.packet_types.update, #data, packet_flags)..data)
            end
        elseif (packet_type == poroNet.packet_types.craft) then
            print("Server requested a craft")
            handle_craft_request(socket, poroNet.get_header_length(data))
        end
      end
      os.sleep(update_delay)
    end

    -- Close the socket when done
    socket.close()
else
    print("Connection failed.")
end
