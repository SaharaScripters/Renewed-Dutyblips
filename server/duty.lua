local Config = require 'config.server'

local duty = {}
local dutyBlips = {}

function duty.TriggerOfficerEvent(eventName, eventData)
    for source, _ in pairs(dutyBlips) do
        TriggerClientEvent(eventName, source, eventData)
    end
end

function duty.getDutyPlayers()
    return dutyBlips
end

local function getPlayerGroups(source)
    local player = exports.qbx_core:GetPlayer(source)
    local groups = {}
    if player then
        groups[player.PlayerData.job.name] = player.PlayerData.job.grade.level
        groups[player.PlayerData.gang.name] = player.PlayerData.gang.grade.level
    end
    return groups
end

local function groupCheck(source)
    local groups = getPlayerGroups(source)

    for job, color in pairs(Config.dutyJobs) do
        if groups[job] then
            return color
        end
    end

    return false
end

function duty.isDuty(source)
    return dutyBlips[source]
end

function duty.add(source)
    local player = exports.qbx_core:GetPlayer(source)
    local playerData = player.PlayerData
    local jobColor = groupCheck(source)

    if jobColor then
        dutyBlips[source] = {
            name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname,
            ped = GetPlayerPed(source),
            color = jobColor
        }

        Player(source).state:set('renewed_dutyblips', dutyBlips[source], true)
    end
end

function duty.remove(source, forced)
    local hasItem = not forced and exports.ox_inventory:GetItemCount(source, Config.itemName) > 0

    if not hasItem or forced then
        dutyBlips[source] = nil
        Player(source).state:set('renewed_dutyblips', false, true)
        duty.TriggerOfficerEvent('Renewed-Dutyblips:client:removedOfficer', source)
        TriggerClientEvent('Renewed-Dutyblips:client:removeNearbyOfficers', source)
    end
end

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    local isOnDuty = dutyBlips[source]

    if isOnDuty then
        dutyBlips[source] = nil
        Player(source).state:set('renewed_dutyblips', false, true)
    end
end)

AddEventHandler('playerDropped', function()
    local isOnDuty = dutyBlips[source]

    if isOnDuty then
        dutyBlips[source] = nil
        Player(source).state:set('renewed_dutyblips', false, true)
    end
end)

return duty