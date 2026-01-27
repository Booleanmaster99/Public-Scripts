local API = require("api")

local currentworld = 62
local P2PWorlds = {
    1, 5, 6, 9, 10, 12, 14, 15, 16, 21, 22, 23, 24, 25, 26, 27, 28, 31, 32, 35, 36, 37, 39, 40, 44, 45,
    46, 49, 50, 51, 53, 54, 58, 59, 60, 62, 63, 64, 65, 67, 68, 69, 70, 71, 72, 73, 74, 76, 77, 78, 79,
    82, 83, 85, 88, 89, 91, 92, 97, 98, 99, 100, 103, 104, 105, 106, 116, 117, 119, 123, 124, 134, 138,
    140, 139, 252, 257, 258, 259
}

local generatedWorlds = {}

local function generateRandomWorld()
    math.randomseed(os.time())
    local selectedWorld = P2PWorlds[math.random(1, #P2PWorlds)]
    return selectedWorld
end

local function getNewWorld()
    local currentTime = os.time()

    local function isWorldGeneratedWithinCooldown(worldName)
        local lastGeneratedTime = generatedWorlds[worldName]
        return lastGeneratedTime and currentTime - lastGeneratedTime < 300
    end

    local selectedWorld = generateRandomWorld()

    while isWorldGeneratedWithinCooldown(selectedWorld) do
        selectedWorld = generateRandomWorld()
    end

    generatedWorlds[selectedWorld] = currentTime

    return selectedWorld
end

function worldhop()
    local newWorld = getNewWorld()
    print("Hopping to world: " .. newWorld)
    API.DoAction_Interface(0xffffffff,0xffffffff,1,1431,0,7,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(3000, 500, 200)
    API.DoAction_Interface(0x24, 0xffffffff,1,1433,66,-1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(3000, 500, 200)
    API.DoAction_Interface(0xffffffff,0xffffffff,1,1587,10,newWorld,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(2000, 1000, 500)
    API.DoAction_Interface(0x24, 0xffffffff,1,1587,97,-1,API.OFF_ACT_GeneralInterface_route)
end

return {
    worldhop = worldhop,
    getNewWorld = getNewWorld,
    P2PWorlds = P2PWorlds
}