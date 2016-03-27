GAME_BUSH_TICK_TIME = 30

function ITT:SpawnBushes()
    Containers:SetDisableItemLimit(true)
    Containers:UsePanoramaInventory(false)

    local bushSpawnerTable = GameRules.BushInfo["BushSpawnInfo"]["SpawnerNames"]
    GameRules.Bushes = {}
    Spawns.bushCount = {}
    Spawns.bushCount["World"]= {{}}
    Spawns.bushCount["Island"]= {{},{},{},{}}
    for bushItem,_ in pairs(bushSpawnerTable) do
        Spawns.bushCount["World"][1][bushItem] = 0
        for i,_ in pairs(REGIONS) do
            Spawns.bushCount["Island"][i][bushItem] = 0
        end
    end
    GameRules.PredefinedBushLocations = GetPredefinedBushLocations(bushSpawnerTable)
    local locationType =  GameRules.BushSpawnLocationType
    local regionType = GameRules.BushSpawnRegion
    for bushItem,_ in pairs(bushSpawnerTable) do
        SpawnBushes(bushItem, regionType, locationType)
    end

    local bushCount = #GameRules.Bushes
    print("Spawned "..bushCount.." bushes total")

    Timers:CreateTimer(function()
        ITT:OnBushThink()
        return GAME_BUSH_TICK_TIME
    end)
end


function SpawnBushes(bushItem, regionType, locationType)
    if regionType == "World"  then
        SpawnBushesCommon(bushItem, locationType, regionType, WORLD)
    elseif regionType == "Island" then
        SpawnBushesCommon(bushItem, locationType,regionType, REGIONS)
    end
end

function SpawnBushesCommon(bushItem, locationType, regionType, regions)
    local bushMaxTable = GameRules.BushInfo["BushSpawnInfo"]['Max'][regionType]
    for i,region in pairs(regions)  do
        for count=1,bushMaxTable[bushItem] do
            local spawnLocation = GetBushSpawnLocation(bushItem, region, locationType)
            if spawnLocation then
                CreateBushContainer(bushItem, spawnLocation)
            end
            Spawns.bushCount[regionType][i][bushItem] = Spawns.bushCount[regionType][i][bushItem] + 1
        end
    end
end

function GetPredefinedBushLocations(bushSpawnerTable)
    local allSpawners = Entities:FindAllByClassname("npc_dota_spawner")
    local bushSpawners = {}
    for bushItem,_ in pairs(bushSpawnerTable) do
        bushSpawners[bushItem] = {}
    end
    for _,spawner in pairs(allSpawners) do
        local spawnerName = spawner:GetName()
        if string.find(spawnerName, "_bush_") then
            local cutoff = string.find(spawnerName,"s")
            local bushName = "npc_".. string.gsub(string.sub(spawnerName, cutoff), "spawner_npc_", "")
            local itemName = "item_"..bushName
--            print("bushname " .. bushName)
            table.insert(bushSpawners[bushName],spawner)
        end
    end
    return bushSpawners
end

function GetBushSpawnLocation(bushItem, region, locationType)
    local location
    if locationType == "random" then
        location = GetRandomBushLocation(region, bushItem)
    elseif locationType == "predefined" then
        location = GetPredefinedBushLocation(region, bushItem)
    elseif locationType == "mix" then
        if RollPercentage(50) then
            location = GetRandomBushLocation(region, bushItem)
        else
            location = GetPredefinedBushLocation(region,  bushItem)
        end
    end
    return location
end

-- Creates a neutral on a predefined spawner position
function GetPredefinedBushLocation(region, bushItem)
    local locations = GetPredefinedBushLocationsOnRegion(region, bushItem)
    if not locations then
        print("ERROR: no spawner locations stored for "..bushItem)
    end
    local location = GetEmptyLocation(locations)
    return location
end

function GetPredefinedBushLocationsOnRegion(region, bushItem)
    local locations  = {}
    for _,predefinedLocation in pairs(GameRules.PredefinedBushLocations[bushItem]) do
        local location = predefinedLocation:GetAbsOrigin()
        if IsVectorInBounds(location, region[1], region[2], region[4], region[3]) and not IsNearABush(location, bushItem) then
            table.insert(locations, location)
        end
    end
    return locations
end

function IsNearABush(location, bushItem)
    local nearbyBushes = Entities:FindAllByClassnameWithin("npc_dota_creature", location, 200)
    for _,bushName in pairs(nearbyBushes) do
        if bushName:GetUnitName() == bushItem then
            return true
        end
    end
    return false
end

-- Creates a nutral on a random location
function GetRandomBushLocation(region, bushItem)
    local location = GetRandomVectorGivenBounds(region[1], region[2], region[3], region[4])
    while IsNearABush(location, bushItem) do
        location = GetRandomVectorGivenBounds(region[1], region[2], region[3], region[4])
    end
    return location
end

function ITT:OnBushThink()
    print("--Creating Items on Bushes--")
    
    local bushes = GameRules.Bushes

    for k,bush in pairs(bushes) do
--        print("Bush name.."..bush:GetContainedItem():GetAbilityName())
        if bush.RngWeight == nil then --rng weight maks it so there's a chance a bush won't spawn but you won't get rng fucked
            bush.RngWeight = 0 --if rng weight doesnt exist declare it to a value that's unlikely to spawn for the first few ticks
        end

        local rand = RandomInt(-4,4) --randomize between -4 and +4, since the min is 0 with the best rng on the minimum number you will still not get a spawn
        local items = bush.container:GetAllItems()
        if rand + bush.RngWeight >= 5 and #items <= 6 then
            bush.RngWeight = bush.RngWeight - 1 --if spawn succeeds reduce the odds of the next spawn

            local bush_name = bush:GetUnitName()
            local bushTable = GameRules.BushInfo["Bushes"][bush_name]
            local possibleChoices = TableCount(bushTable)
            local randomN = tostring(RandomInt(1, possibleChoices))
            local bush_random_item = bushTable[randomN]

            --GiveItemStack(bush, bush_random_item)
            bush.container:AddItem(CreateItem(bush_random_item, nil, nil)) --Missing stack handling
--            print("adding " .. bush_random_item .. " to ".. bush_name)

        else
            bush.RngWeight = bush.RngWeight + 1 --if spawn fails increase odds for next run
        end
    end

    return GAME_BUSH_TICK_TIME
end

function CreateBushContainer( name, position )
    --local newItem = CreateItem(name, nil, nil)
    --local bush = CreateItemOnPositionSync(position, newItem)
    print("spawning bush " .. name)
    local bush = CreateUnitByName(name, position, true, nil, nil, DOTA_TEAM_NEUTRALS)
    --( szUnitName, vLocation, bFindClearSpace, hNPCOwner, hUnitOwner, iTeamNumber )

    --Particle refused to show through fog for an hour so give vision instead
    for _,v in pairs(VALID_TEAMS) do AddFOWViewer ( v, position, 100, 0.1, false) end

    table.insert(GameRules.Bushes, bush)

    local cont = Containers:CreateContainer({
        layout =      {3,3},
        --skins =       {"Hourglass"},
        headerText =  name,
        buttons =     {"Grab All"},
        position =    "entity", --"mouse",--"900px 200px 0px",
        draggable = false,
        closeOnOrder= true,
        items = {},
        entity = bush,
        range = DEFAULT_TRANSFER_RANGE,
        OnDragWorld = true,

        OnLeftClick = function(playerID, container, unit, item, slot)

            container:RemoveItem(item)
            Containers:AddItemToUnit(unit,item)

            --[[if CanTakeMoreItems(unit) or CanTakeMoreStacksOfItem(unit, item) then
                unit:StartGesture(ACT_DOTA_ATTACK)

                TransferItem(container, unit, item)

            else
                SendErrorMessage(playerID, "#error_inventory_full")
            end]]
        end,

        OnButtonPressed = function(playerID, container, unit, button, buttonName)
            if button == 1 then
                local items = container:GetAllItems()

                for _,item in ipairs(items) do

                    --TransferItem(container, unit, item)
                    container:RemoveItem(item)
                    Containers:AddItemToUnit(unit,item)

                end

                container:Close(playerID)
            end
        end,

        OnEntityOrder = function(playerID, container, unit, target)
            --[[if (bush:GetUnitName() == "npc_bush_scout" and unit:GetClassname() ~= "npc_dota_hero_lion") then
                SendErrorMessage(playerID, "#error_scout_only_bush")
                return --exits if bush is used by anything other than a scout
            end

            if (bush:GetUnitName() == "npc_bush_thief" and unit:GetClassname() ~= "npc_dota_hero_riki") then
                SendErrorMessage(playerID, "#error_thief_only_bush")
                return --exits if bush is used by anything other than a thief
            end]]
            
            print("ORDER ACTION loot box: ", playerID)
            container:Open(playerID)
            unit:Stop()
            unit:Hold()
        end,
    })

    bush.container = cont
    bush.phys = phys

    --Containers:SetDefaultInventory(bush, container)
end