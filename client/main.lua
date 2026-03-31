local isMenuOpen = false

local function TakeMugshot()
    if GetResourceState('MugShotBase64') == 'started' then
        local ped = PlayerPedId()
        local mugshot = exports["MugShotBase64"]:GetMugShotBase64(ped, true)
        
        if mugshot and mugshot ~= "" then
            TriggerServerEvent('perc-economy:server:saveMugshot', mugshot)
            if config.prints then lib.print.info("Mugshot captured and sent to server!") end
        else
            if config.prints then lib.print.error("MugShotBase64 export failed to return an image.") end
        end
    else
        if config.prints then lib.print.info("MugShotBase64 script is not running.") end
    end
end

RegisterNetEvent('perc-economy:client:openUI', function(data)
    if isMenuOpen then return end
    
    isMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openDashboard",
        dashboardData = data,
        theme = config.colors
    })
end)

RegisterNetEvent('perc-economy:client:refreshMugshot', function()
    TakeMugshot()
end)

local function VerifyMugshot()
    local needsMugshot = lib.callback.await('perc-economy:checkMugshot', 500)
    if needsMugshot then
        SetTimeout(8000, function() TakeMugshot() end)
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', VerifyMugshot)
RegisterNetEvent('qbx_core:client:playerLoaded', VerifyMugshot)
RegisterNetEvent('esx:playerLoaded', VerifyMugshot)

RegisterNUICallback('closeUI', function(_, cb)
    isMenuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('actionMoney', function(data, cb)
    local success = lib.callback.await('perc-economy:actionMoney', 500, data)
    if success then
        lib.notify({title = 'Success', description = 'Economy data successfully updated.', type = 'success'})
    else
        lib.notify({title = 'Error', description = 'Failed to update economy data. Do you have permission?', type = 'error'})
    end
    cb('ok')
end)
