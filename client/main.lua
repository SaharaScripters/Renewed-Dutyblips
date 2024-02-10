local Blips = require 'client.blip'
local playerBlips = {}
local audioPlayers = {}
local dutyBlips = GlobalState.dutyJobs
local isWhitelisted = false

local Utils = require 'client.utils'

local function isGroupsWhitelisted(groups)
    if groups then
        for group, _ in pairs(dutyBlips) do
            if groups[group] then
                return true
            end
        end
    end
end

local getGroups = function()
    local groups = {}
    if dutyBlips[QBX.PlayerData.job.name] then
        groups[QBX.PlayerData.job.name] = QBX.PlayerData.job.grade.level
    end
    if dutyBlips[QBX.PlayerData.gang.name] then
        groups[QBX.PlayerData.gang.name] = QBX.PlayerData.gang.grade.level
    end
    return groups
end

local groupUpdated = function()
    local wasWhitelisted = isWhitelisted

    isWhitelisted = isGroupsWhitelisted(getGroups())

    if wasWhitelisted ~= isWhitelisted then
        if next(playerBlips) then
            for source, blip in pairs(playerBlips) do
                RemoveBlip(blip)
                playerBlips[source] = nil
            end
        end
        TriggerServerEvent('Renewed-Dutyblips:server:updateMeBlip', isWhitelisted)
    end
end

local NetworkIsPlayerActive = NetworkIsPlayerActive
local GetPlayerFromServerId = GetPlayerFromServerId
local DoesBlipExist = DoesBlipExist


local function createPedBlip(blipData)
    local playerId = GetPlayerFromServerId(blipData.source)
    local currentBlip = playerBlips[blipData.source]
    local blipExsist = DoesBlipExist(currentBlip)
    local playerNearby = NetworkIsPlayerActive(playerId)

    if blipExsist and playerNearby then
        return
    end

    if not blipExsist and playerNearby then
        local pedHandle = Utils.awaitPedHandle(playerId)

        if pedHandle then
            return Blips.addBlipForEntity(pedHandle, blipData)
        end
    end

    if not playerNearby and not blipExsist then
        return Blips.addBlipForCoord(blipData.coords, blipData)
    end

    SetBlipCoords(currentBlip, blipData.coords.x, blipData.coords.y, blipData.coords.z)

    return false
end

Utils.registerNetEvent('Renewed-Dutyblips:client:updateDutyBlips', function(data)
    for i = 1, #data do
        local blipData = data[i]
        local source = blipData.source
        if source ~= cache.serverId then
            local blip = createPedBlip(blipData)

            if blip then
                playerBlips[source] = blip
            end
        end
    end
end)

local enableTrackerAudio = require 'config.client'.enableTrackerAudio
local myId = ('player:%s'):format(cache.serverId)
local playerState = LocalPlayer.state
AddStateBagChangeHandler('renewed_dutyblips', nil, function(bagName, _, value)
    local source = tonumber(bagName:gsub('player:', ''), 10)

    local blip = playerBlips[source]
    local playerId = GetPlayerFromServerId(source)
    local pedHandle = Utils.awaitPedHandle(playerId)

    if not value then
        if blip then
            RemoveBlip(blip)
            playerBlips[source] = nil
        end

        if pedHandle and enableTrackerAudio then
            local index = lib.table.contains(audioPlayers, pedHandle)

            if index and index > 0 then
                audioPlayers[index] = nil
            end
        end

        return
    end

    if enableTrackerAudio and not lib.table.contains(audioPlayers, pedHandle) then
        audioPlayers[#audioPlayers+1] = pedHandle
        Utils.playEntityAudio(pedHandle)
    end

    if isWhitelisted and bagName ~= myId and playerState.renewed_dutyblips then
        if pedHandle then
            if blip then
                RemoveBlip(blip)
            end

            playerBlips[source] = Blips.addBlipForEntity(pedHandle, value)
        end
    end
end)

CreateThread(function()
    while true do
        if isWhitelisted and next(playerBlips) then
            for source, blip in pairs(playerBlips) do
                local playerId = GetPlayerFromServerId(source)

                if NetworkIsPlayerActive(playerId) then
                    local playerPed = Utils.awaitPedHandle(playerId)

                    if playerPed then
                        Blips.changeBlipForEntity(blip, playerPed)
                    end

                end
            end
        end
        Wait(1500)
    end
end)

if enableTrackerAudio then
    CreateThread(function()
        while true do
            if next(audioPlayers) then
                for i = 1, #audioPlayers do
                    local ped = audioPlayers[i]

                    if DoesEntityExist(ped) then
                        Utils.playEntityAudio(ped)
                    else
                        audioPlayers[i] = nil
                    end

                    Wait(math.random(100, 500))
                end
            end

            Wait(math.random(9, 15) * 1000)
        end
    end)
end

Utils.registerNetEvent('Renewed-Dutyblips:client:removeNearbyOfficers', function()
    if next(playerBlips) then
        for source, blip in pairs(playerBlips) do
            RemoveBlip(blip)
            playerBlips[source] = nil
        end
    end
end)

Utils.registerNetEvent('Renewed-Dutyblips:client:removedOfficer', function(officerSource)
    local blip = playerBlips[officerSource]

    if blip then
        RemoveBlip(blip)
        playerBlips[officerSource] = nil
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isWhitelisted = isGroupsWhitelisted(getGroups())
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    groupUpdated()
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function()
    groupUpdated()
end)



AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        isWhitelisted = isGroupsWhitelisted(getGroups())
    end
end)