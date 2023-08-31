local M = {}

M.packet_types = { acknowledgement = 0, update = 1, account = 2, identification = 3, craft = 5}
M.inverted_packet_types = {}
-- Invert the packet_type table
for key, value in pairs(M.packet_types) do
    M.inverted_packet_types[value] = key
end


M.flags = {
    update = {
        ITEM = 0,
        ENERGY = 2,
        CPUS = 4,
        CRAFT = 8,
        ALL = 16,
    },
    account = {
        SUCCESS = 0,
        FAILURE = 0,
    },
}



function M.create_header(type, length, flags)
    local packet_bytes = string.char(type)
    
    -- Extract and add each byte of the length
    for i = 3, 0, -1 do
        local byte = math.floor(length / (256 ^ i)) % 256
        packet_bytes = packet_bytes .. string.char(byte)
    end

    packet_bytes = packet_bytes .. string.char(flags)
    return packet_bytes
end

function M.packet_id(id, version)
    id = tostring(id)
    payload = id..";"..tostring(version)
    packet_header = M.create_header(M.packet_types.identification, #payload, 0)
    return packet_header..payload
end

function M.packet_account(name, id, password)
    name = tostring(name)
    id = tostring(id)
    password = tostring(password)
    packet_header = M.create_header(M.packet_types.account, 2+ #name+ #id+ #password, 0)
    packet_payload = name..';'..id..';'..password
    return packet_header..packet_payload
end

function M.get_header_type(packet)
    local header_type = string.unpack(">I1", packet, 1)
    return header_type
end

function M.get_header_length(packet)
    local header_len = string.unpack(">I4", packet, 2)
    return header_len
end

function M.get_header_flag(packet)
    local header_flags = string.unpack(">I1", packet, 6)
    return header_flags
end


function M.print_byte_array(byteArray)
    for i = 1, #byteArray do
        local byteValue = byteArray:byte(i)
        io.write(string.format("x%02X", byteValue))
        if i < #byteArray then
            io.write(", ") -- Add a comma and space for separation
        end
    end
    io.write("\n") -- Print a newline at the end
end

function M.sendall(socket, data)
    local remaining = #data
    local MTU = 2048
    local current_packet = 0
    while remaining > 0 do
        local sub_packet = string.sub(data, (current_packet*MTU) + 1, ((current_packet+1)*MTU) +1)
        socket.write(sub_packet)
        remaining = remaining - MTU
        current_packet = current_packet + 1
    end
end

return M