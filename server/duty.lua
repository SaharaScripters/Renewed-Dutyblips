local currentDuty = {}
local jobs = require 'config.server'.dutyJobs


local function groupCheck(playerGroups)
    for job, color in pairs(jobs) do
        if playerGroups[job] then
            return color
        end
    end

    return false
end

local function triggerDutyEvent(eventName, eventData)
    for i = 1, #currentDuty do
        TriggerClientEvent(eventName, currentDuty[i].source, eventData)
    end
end

local function isCopOnDuty(source)
    for i = 1, #currentDuty do
        if currentDuty[i].source == source then
            return i
        end
    end

    return false
end

local function addPolice(source)
    if not isCopOnDuty(source) then
        local player = exports.qbx_core:GetPlayer(source)
        if not player then
            return
        end
        local playerData = {
            name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            Groups = exports.qbx_core:GetGroups(source)
        }
        local getBlipColor = groupCheck(playerData.Groups)

        if getBlipColor then
            Player(source).state:set('renewed_dutyblips', true, true)

            local copData = {
                name = playerData.name,
                ped = GetPlayerPed(source),
                source = source,
                color = getBlipColor
            }

            currentDuty[#currentDuty+1] = copData

            triggerDutyEvent('Renewed-Dutyblips:addOfficer', copData)
            TriggerClientEvent('Renewed-Dutyblips:goOnDuty', source, currentDuty)

            return true
        end
    end

    return false
end

local function removePolice(source)
    local index = isCopOnDuty(source)

    if index then
        table.remove(currentDuty, index)
        Player(source).state:set('renewed_dutyblips', false, true)
        triggerDutyEvent('Renewed-Dutyblips:removeOfficer', index)
        TriggerClientEvent('Renewed-Dutyblips:goOffDuty', source)
    end
end

return {
    add = addPolice,
    remove = removePolice,
    onDuty = isCopOnDuty,
    getCopsOnDuty = function()
        return currentDuty
    end,
    triggerDutyEvent = triggerDutyEvent
}


