local framework = 'none'

CreateThread(function()
    if GetResourceState('qbx_core') == 'started' then 
        framework = 'qbox'
    elseif GetResourceState('qb-core') == 'started' then 
        framework = 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then 
        framework = 'esx'
    else
        if config.prints then lib.print.error("No supported framework found!") end
        return
    end

    if config.prints then lib.print.info("Verifying database structure...") end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `economy_history` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
            `total_cash` bigint(20) NOT NULL DEFAULT 0,
            `total_bank` bigint(20) NOT NULL DEFAULT 0,
            `total_dirty` bigint(20) NOT NULL DEFAULT 0,
            `total` bigint(20) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local tableName = (framework == 'esx') and 'users' or 'players'
    
    local cols = MySQL.query.await(('SHOW COLUMNS FROM `%s`'):format(tableName))
    local hasMugshot, hasDiscord, hasFivem, hasSteam = false, false, false, false

    for i = 1, #cols do
        local colName = cols[i].Field
        if colName == "mugshot" then hasMugshot = true
        elseif colName == "discord" then hasDiscord = true
        elseif colName == "fivem" then hasFivem = true
        elseif colName == "steam" then hasSteam = true end
    end

    if not hasMugshot then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `mugshot` LONGTEXT DEFAULT NULL'):format(tableName))
        if config.prints then lib.print.info(('Injected "mugshot" column into `%s` table.'):format(tableName)) end
    end
    if not hasDiscord then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `discord` VARCHAR(50) DEFAULT NULL'):format(tableName))
        if config.prints then lib.print.info(('Injected "discord" column into `%s` table.'):format(tableName)) end
    end
    if not hasFivem then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `fivem` VARCHAR(50) DEFAULT NULL'):format(tableName))
        if config.prints then lib.print.info(('Injected "fivem" column into `%s` table.'):format(tableName)) end
    end
    if not hasSteam then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `steam` VARCHAR(50) DEFAULT NULL'):format(tableName))
        if config.prints then lib.print.info(('Injected "steam" column into `%s` table.'):format(tableName)) end
    end

    if config.prints then lib.print.info("Database verified and ready.") end
end)

local function ExtractIdentifiers(src)
    local discord = GetPlayerIdentifierByType(src, 'discord') or ""
    local fivem = GetPlayerIdentifierByType(src, 'fivem') or ""
    local steam = GetPlayerIdentifierByType(src, 'steam') or ""
    return discord, fivem, steam
end

local function HandlePlayerLoaded(src, identifier, tableTarget, identifierColumn)
    local discord, fivem, steam = ExtractIdentifiers(src)
    MySQL.update(('UPDATE %s SET discord = ?, fivem = ?, steam = ? WHERE %s = ?'):format(tableTarget, identifierColumn), {discord, fivem, steam, identifier})
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
    if player then HandlePlayerLoaded(src, player.PlayerData.citizenid, 'players', 'citizenid') end
end)

RegisterNetEvent('qbx_core:server:onPlayerLoaded', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if player then HandlePlayerLoaded(src, player.PlayerData.citizenid, 'players', 'citizenid') end
end)

RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
    HandlePlayerLoaded(playerId, xPlayer.identifier, 'users', 'identifier')
end)

local function GetDatabaseEconomy()
    local playersData = {}
    local totalCash, totalBank, totalDirty = 0, 0, 0

    if framework == 'qbox' or framework == 'qbcore' then
        local result = MySQL.query.await('SELECT citizenid, charinfo, money, job, discord, fivem, license, steam, metadata, mugshot FROM players')

        for i = 1, #result do
            local row = result[i]
            local charinfo = row.charinfo and json.decode(row.charinfo) or {}
            local money = row.money and json.decode(row.money) or {}
            local job = row.job and json.decode(row.job) or {}

            local cash = money.cash or 0
            local bank = money.bank or 0
            local dirty = (money.black_money or 0) + (money.crypto or 0) 

            totalCash, totalBank, totalDirty = totalCash + cash, totalBank + bank, totalDirty + dirty

            local searchString = string.format("%s %s %s %s %s %s", row.discord or "", row.fivem or "", row.license or "", row.steam or "", type(row.metadata) == "string" and row.metadata or "", row.citizenid):lower()

            playersData[#playersData + 1] = {
                id = row.citizenid,
                name = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or ''),
                job = job.label or 'Unemployed',
                cash = cash, bank = bank, dirty = dirty,
                total = cash + bank + dirty,
                mugshotbase64 = row.mugshot or false,
                searchString = searchString 
            }
        end

    elseif framework == 'esx' then
        local result = MySQL.query.await('SELECT identifier, accounts, discord, fivem, license, steam, firstname, lastname, job, mugshot FROM users')

        for i = 1, #result do
            local row = result[i]
            local accounts = row.accounts and json.decode(row.accounts) or {}
            local cash = accounts.money or 0
            local bank = accounts.bank or 0
            local dirty = accounts.black_money or 0

            totalCash, totalBank, totalDirty = totalCash + cash, totalBank + bank, totalDirty + dirty
            local searchString = string.format("%s %s %s %s", row.discord or "", row.fivem or "", row.license or "", row.steam or "", row.identifier or ""):lower()

            playersData[#playersData + 1] = {
                id = row.identifier,
                name = (row.firstname or 'Unknown') .. ' ' .. (row.lastname or ''),
                job = row.job or 'Unemployed',
                cash = cash, bank = bank, dirty = dirty,
                total = cash + bank + dirty,
                mugshotbase64 = row.mugshot or false,
                searchString = searchString
            }
        end
    end

    table.sort(playersData, function(a, b) return a.total > b.total end)
    return playersData, totalCash, totalBank, totalDirty, totalCash + totalBank + totalDirty
end

lib.addCommand(config.commands.open, {
    help = 'Open Economy Dashboard',
    restricted = config.commands.perms
}, function(source, args, raw)
    local players, cash, bank, dirty, total = GetDatabaseEconomy()

    local dayRes = MySQL.query.await('SELECT DATE_FORMAT(timestamp, "%H:%00") as time, AVG(total_cash) as total_cash, AVG(total_bank) as total_bank, AVG(total_dirty) as total_dirty FROM economy_history WHERE timestamp >= NOW() - INTERVAL 1 DAY GROUP BY DATE_FORMAT(timestamp, "%Y-%m-%d %H:00") ORDER BY timestamp ASC')
    local monthRes = MySQL.query.await('SELECT DATE_FORMAT(timestamp, "%b %d") as time, AVG(total_cash) as total_cash, AVG(total_bank) as total_bank, AVG(total_dirty) as total_dirty FROM economy_history WHERE timestamp >= NOW() - INTERVAL 30 DAY GROUP BY DATE(timestamp) ORDER BY timestamp ASC')

    local history = { day = dayRes, month = monthRes }

    if #history.day == 0 then
        local fallback = {{ time = os.date("%H:00"), total_cash = cash, total_bank = bank, total_dirty = dirty, total = total }}
        history.day, history.month = fallback, {{ time = os.date("%b %d"), total_cash = cash, total_bank = bank, total_dirty = dirty, total = total }}
        MySQL.insert.await('INSERT INTO economy_history (total_cash, total_bank, total_dirty, total) VALUES (?, ?, ?, ?)', { cash, bank, dirty, total })
    end

    local dashboardData = { players = players, history = history, serverTotal = total }
    TriggerClientEvent('perc-economy:client:openUI', source, dashboardData)
end)

lib.addCommand(config.commands.refresh, {
    help = 'Refresh your mugshot for the economy dashboard',
    restricted = config.commands.perms
}, function(source, args, raw)
    TriggerClientEvent('perc-economy:client:refreshMugshot', source)
end)

lib.callback.register('perc-economy:actionMoney', function(source, data)
    local hasPerm = false
    if config.commands.perms then
        for i = 1, #config.commands.perms do
            if IsPlayerAceAllowed(source, config.commands.perms[i]) then hasPerm = true; break; end
        end
    end
    if not hasPerm then return false end

    local action, identifier = data.action, data.identifier
    local newCash, newBank, newDirty = data.cash or 0, data.bank or 0, data.dirty or 0
    if action == 'wipe' then newCash, newBank, newDirty = 0, 0, 0 end

    if framework == 'qbox' or framework == 'qbcore' then
        local player = (framework == 'qbcore') and exports['qb-core']:GetCoreObject().Functions.GetPlayerByCitizenId(identifier) or exports.qbx_core:GetPlayerByCitizenId(identifier)
        
        if player then
            player.Functions.SetMoney('cash', newCash, "admin-dashboard")
            player.Functions.SetMoney('bank', newBank, "admin-dashboard")
            if player.PlayerData.money.crypto then player.Functions.SetMoney('crypto', newDirty, "admin-dashboard") end
        else
            local row = MySQL.scalar.await('SELECT money FROM players WHERE citizenid = ?', {identifier})
            if row then
                local money = json.decode(row) or {}
                money.cash, money.bank = newCash, newBank
                if money.black_money then money.black_money = newDirty end
                if money.crypto then money.crypto = newDirty end 
                MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {json.encode(money), identifier})
            end
        end
    elseif framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        local player = ESX.GetPlayerFromIdentifier(identifier)
        
        if player then
            player.setAccountMoney('money', newCash)
            player.setAccountMoney('bank', newBank)
            player.setAccountMoney('black_money', newDirty)
        else
            local row = MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = ?', {identifier})
            if row then
                local accounts = json.decode(row) or {}
                accounts.money, accounts.bank, accounts.black_money = newCash, newBank, newDirty
                MySQL.update('UPDATE users SET accounts = ? WHERE identifier = ?', {json.encode(accounts), identifier})
            end
        end
    end

    if config.prints then lib.print.info(("Admin ID %s modified economy data for identifier: %s"):format(source, identifier)) end
    return true
end)

RegisterNetEvent('perc-economy:server:saveMugshot', function(base64String)
    local src = source
    if not base64String then return end

    if config.prints then lib.print.info(("Received mugshot from player id: %s"):format(src)) end

    if framework == 'qbox' or framework == 'qbcore' then
        local player = (framework == 'qbox') and exports.qbx_core:GetPlayer(src) or exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
        if player then MySQL.update('UPDATE players SET mugshot = ? WHERE citizenid = ?', {base64String, player.PlayerData.citizenid}) end
    elseif framework == 'esx' then
        local player = exports['es_extended']:getSharedObject().GetPlayerFromId(src)
        if player then MySQL.update('UPDATE users SET mugshot = ? WHERE identifier = ?', {base64String, player.identifier}) end
    end
end)

lib.callback.register('perc-economy:checkMugshot', function(source)
    local identifier = nil
    if framework == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        if player then identifier = player.PlayerData.citizenid end
    elseif framework == 'qbcore' then
        local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
        if player then identifier = player.PlayerData.citizenid end
    elseif framework == 'esx' then
        local player = exports['es_extended']:getSharedObject().GetPlayerFromId(source)
        if player then identifier = player.identifier end
    end

    if identifier then
        local tableName, idColumn = (framework == 'esx') and 'users' or 'players', (framework == 'esx') and 'identifier' or 'citizenid'
        local result = MySQL.scalar.await(('SELECT mugshot FROM %s WHERE %s = ?'):format(tableName, idColumn), {identifier})
        if not result or result == "" or result == "false" then return true end
    end
    return false
end)

SetInterval(function()
    local _, cash, bank, dirty, total = GetDatabaseEconomy()
    MySQL.insert('INSERT INTO economy_history (total_cash, total_bank, total_dirty, total) VALUES (?, ?, ?, ?)', { cash, bank, dirty, total })
end, 60000 * config.update)
