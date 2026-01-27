local API = require("api")
local UTILS = require("utils")
local worldhop = require("worldhopper")


MAX_IDLE_TIME_MINUTES = 4
afk = os.time()
local CURSOR_LOCATION_VARBIT_ID = 174
local JagexAccount = true 
local door13 = 52302
local door46 = 52304
local ThievingLevel = API.XPLevelTable(API.GetSkillXP("THIEVING"))
local startTime = os.time()
local startXp = API.GetSkillXP("THIEVING")
local gatesopened, fail = -1, 0
local skillxpsold = 0
local lastXpDropTime = os.time()
local currentworld = 32

local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

local function formatNumberWithCommas(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

local function printProgressReport(final)
    skillxps = API.GetSkillXP("THIEVING")
    if (skillxps ~= skillxpsold) then
        skillxpsold = skillxps
        gatesopened = gatesopened + 1
    end
    local currentXp = API.GetSkillXP("THIEVING")
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp)
    local xpPH = round((diffXp * 60) / elapsedMinutes)
    local gatesopenedPH = round((gatesopened * 60) / elapsedMinutes)
    local time = formatElapsedTime(startTime)
    IG.string_value = " Thieving XP : " .. formatNumberWithCommas(diffXp) .. " (" .. formatNumberWithCommas(xpPH) .. ")"
    IG2.string_value = "   Gates Opened : " .. formatNumberWithCommas(gatesopened) .. " (" .. formatNumberWithCommas(gatesopenedPH) .. ")"
    IG4.string_value = time

    if final then
        print(os.date("%H:%M:%S") .. " Script Finished\nRuntime : " .. time .. "\nTHIEVING XP : " .. formatNumberWithCommas(diffXp) .. " \nGates opened : " .. formatNumberWithCommas(gatesopened))
    end
end

local function setupGUI()
    IG = API.CreateIG_answer()
    IG.box_start = FFPOINT.new(15, 50, 0)
    IG.box_name = "THIEVING"
    IG.colour = ImColor.new(255, 255, 255);
    IG.string_value = "THIEVING XP : 0 (0)"

    IG2 = API.CreateIG_answer()
    IG2.box_start = FFPOINT.new(1, 65, 0)
    IG2.box_name = "gatesopenedT"
    IG2.colour = ImColor.new(255, 255, 255);
    IG2.string_value = " Gates Opened : 0 (0)"

    IG3 = API.CreateIG_answer()
    IG3.box_start = FFPOINT.new(40, 15, 0)
    IG3.box_name = "TITLE"
    IG3.colour = ImColor.new(0, 255, 0);
    IG3.string_value = "- Jail Opener v1.0 -"

    IG6 = API.CreateIG_answer()
    IG6.box_start = FFPOINT.new(5, 80, 0)
    IG6.box_name = "LINE"
    IG6.colour = ImColor.new(0, 255, 0);
    IG6.string_value = "-----------------------------------"

    IG7 = API.CreateIG_answer()
    IG7.box_start = FFPOINT.new(5, 5, 0)
    IG7.box_name = "LINE2"
    IG7.colour = ImColor.new(0, 255, 0);
    IG7.string_value = "-----------------------------------"

    IG4 = API.CreateIG_answer()
    IG4.box_start = FFPOINT.new(70, 31, 0)
    IG4.box_name = "TIME"
    IG4.colour = ImColor.new(255, 255, 255);
    IG4.string_value = "[00:00:00]"

    IG_Back = API.CreateIG_answer();
    IG_Back.box_name = "back";
    IG_Back.box_start = FFPOINT.new(0, 0, 0)
    IG_Back.box_size = FFPOINT.new(255, 100, 0)
    IG_Back.colour = ImColor.new(15, 13, 18, 255)
    IG_Back.string_value = ""
end

function drawGUI()
    API.DrawSquareFilled(IG_Back)
    API.DrawTextAt(IG)
    API.DrawTextAt(IG2)
    API.DrawTextAt(IG3)
    API.DrawTextAt(IG4)
    API.DrawTextAt(IG5)
    API.DrawTextAt(IG6)
    API.DrawTextAt(IG7)
end

setupGUI()

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function RandomSleep3(arg1, arg2, arg3)
    local numSteps = 8 

    for i = 1, numSteps do
        local stepDuration1 = arg1 / numSteps
        local stepDuration2 = arg2 / numSteps
        local stepDuration3 = arg3 / numSteps

        API.RandomSleep2(stepDuration1, stepDuration2, stepDuration3)
        printProgressReport()
    end
end

function CheckDoorStatus(doorTile)
    if not API.CheckTileforObjects1(doorTile) then
        return false
    else
        return true
    end
end

local function findNpc(npcid, distance)
    local distance = distance or 25
    return #API.GetAllObjArrayInteract({ npcid }, distance, {1}) > 0
end

local doors = {
    { tile = WPOINT.new(4776, 5916, 0), status = false },
    { tile = WPOINT.new(4778, 5916, 0), status = false },
    { tile = WPOINT.new(4780, 5916, 0), status = false },
    { tile = WPOINT.new(4776, 5915, 0), status = false },
    { tile = WPOINT.new(4778, 5915, 0), status = false },
    { tile = WPOINT.new(4780, 5915, 0), status = false },
}

local doorstruetile = {
    { tile = WPOINT.new(4776, 5917, 0)},
    { tile = WPOINT.new(4778, 5917, 0)},
    { tile = WPOINT.new(4780, 5917, 0)},
    { tile = WPOINT.new(4776, 5914, 0)},
    { tile = WPOINT.new(4778, 5914, 0)},
    { tile = WPOINT.new(4780, 5914, 0)},
}

function checkalldoors()
    for i, door in ipairs(doors) do
        door.status = CheckDoorStatus(door.tile)
    end
end

local function calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end


API.Write_LoopyLoop(1)
API.Write_Doaction_paint(1)
local hasAddedElements = false
local worldhopini = false 
local previousWorld = nil  

while API.Read_LoopyLoop() do
    drawGUI()

    local world = API.GetWorldNR()

  
    if worldhopini and previousWorld and world ~= previousWorld then
        print("World hop complete: " .. previousWorld .. " -> " .. world)
        worldhopini = false
        previousWorld = nil
    end
   
    if API.GetGameState2() == 3 then
        API.RandomSleep2(1000, 500, 2000)
        
        if findNpc(11294) then
            ThievingLevel = API.XPLevelTable(API.GetSkillXP("THIEVING"))
            
            if ThievingLevel >= 15 then
                printProgressReport()
                idleCheck()
                checkalldoors()

                if ThievingLevel < 35 and doors[1].status and doors[2].status and doors[3].status then
                    print("All doors 1-3 are open, trying to world hop")
                    if not worldhopini then
                        previousWorld = world
                        worldhop.worldhop()
                        worldhopini = true
                    end
                end

                if ThievingLevel >= 35 then
                    if doors[1].status and doors[2].status and doors[3].status and doors[4].status and doors[5].status and doors[6].status then
                        print("All doors 1-6 are open, trying to world hop")
                        if not worldhopini then
                            previousWorld = world
                            worldhop.worldhop()
                            worldhopini = true
                        end
                    end
                end

                -- Get the player's coordinates
                local player = API.PlayerCoord()

                local closestDoor = nil
                local closestDistance = math.huge
                local doorId = nil
                local closestDoorIndex = nil

                for i, door in ipairs(doors) do
                    local distance = calculateDistance(player.x, player.y, doorstruetile[i].tile.x, doorstruetile[i].tile.y)
                    
                    local canOpenDoor = (i <= 3) or (ThievingLevel >= 35)
                    
                    if not door.status and distance < closestDistance and canOpenDoor then
                        closestDistance = distance
                        closestDoor = door
                        doorId = (i <= 3) and door13 or door46 
                        closestDoorIndex = i 
                    end
                end

                if closestDoor then
                    print("Door " .. closestDoorIndex .. " is closed, Trying to open...")
                    API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { doorId }, 50, doorstruetile[closestDoorIndex].tile)
                    
                    RandomSleep3(600, 200, 200)
                    API.WaitUntilMovingEnds()
                    RandomSleep3(1100, 200, 200)
                end
            end
        end
        RandomSleep3(600, 200, 200)
    end
end
