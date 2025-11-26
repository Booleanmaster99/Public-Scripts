--ScriptName = "Gnome_Restaurant"
--Author = "BooleanMaster9000"
--ScriptVersion = "0.2"
--ReleaseDate = "xx-xx-xxxx"
--Discord = "BooleanMaster9000"
--[[
Changelog:
v0.0.1 - 01-09-2025
v0.0.2 - 22-09-2025: 48H temp ban (likely interacting out-of-area)  <-- BE CAREFUL
v0.2   - cleanup, single Bank(), constants, map-based task->item, safer timers
]]

local API        = require("api")
local BANK       = require("bank")
local LODESTONES = require("Lodestones")
local Slib       = require("slib")
local UTILS      = require("Utils")

-- =========================
-- Metrics 
-- =========================

-- =========================
-- Constants / IDs
-- =========================
local CFG = {
  VARBIT = {
    HAS_TASK    = 16034, -- 1 when on task
    TASK_ID     = 16039, -- recipe id (14=worm hole, etc.)
    TASK_GIVER  = 16040, -- 103=Ninto, 104=Daerkin
    UI_STATE    = 2874,  -- general interface controller
  },
  UI_STATE = {
    DIALOGUE = 12,
    SHOP     = 18,
    TELEPORT = 18,
  },
  NPC = {
    GIANNE_JNR = 4572,
    DAERKIN    = "Captain Daerkin",
  },
  OBJ = {
    SPIRIT_TREE      = "Spirit tree",
    TREE_DOOR        = "Tree Door",
    LADDER           = 107376, -- object id used in DoAction_Object1
  },
  GIVERS = {
    NINTO  = 103,
    DAERKIN= 104,
  },
  KEYS = {
    ESC   = 0x1B,
    SPACE = 0x20,
    K1    = 0x31,
    K2    = 0x32,
  }
}

-- =========================
-- State
-- =========================
local ReadyToRequest       = true
local TaskState_Finished   = false
local Scarftask            = false
local Ninto, Daerkin       = false, false
local bankaction           = false
local interactionsucces_5  = false
local StartTime            = os.time()
local StartingTime         = API.SystemTime()
local taskStartTime        = 0
local taskDuration         = 0
local taskType             = "hard"   -- "easy" or "hard" only hard is supported 
local lastTimerDisplay     = 0
local watchywatch          = 0

-- Random reject lobby timer (5:35–6:15)
local MinTargetDelay       = (5*60 + 35) * 1000
local MaxTargetDelay       = (6*60 + 15) * 1000
local TargetDelay          = math.random(MinTargetDelay, MaxTargetDelay)

-- =========================
-- Logging
-- =========================
local function log(...)
  print(string.format("[%s]", "GR"), ...)
end

-- =========================
-- Eror_Handler
-- =========================


-- =========================
-- Helpers / UI
-- =========================
local function isDialogueOpen()
  return API.Compare2874Status(CFG.UI_STATE.DIALOGUE, false)
end
local function isShopOpen()
  return API.Compare2874Status(CFG.UI_STATE.SHOP, false)
end
local function isTeleportOpen()
  log (API.Compare2874Status(CFG.UI_STATE.TELEPORT))
  return API.Compare2874Status(CFG.UI_STATE.TELEPORT, false)
end
local function area(x1,x2,y1,y2) return API.PInArea21(x1,x2,y1,y2) end

-- =========================
-- Stats init
-- =========================
API.Write_fake_mouse_do(false)
--Stats:send("Boot")

-- =========================
-- Inventory stock (for metrics)
-- =========================
local ItemsAndAmounts = {
  {2191,1},{2205,1},{2209,1},{2213,1},{2217,1},
  {2185,1},{2195,1},{2187,1},{2259,1},{2277,1},
  {2255,1},{2253,1},{2281,1},{2054,1},{2074,1},
  {2048,1},{2064,1},{2084,1},{2080,1},{2092,1},
}

-- =========================
-- TASK -> ITEM map
-- =========================
local TASK_TO_ITEM = {
  [14]=2191, -- Worm hole
  [16]=2195, -- Veg ball
  [19]=2187, -- Tangled toads' legs
  [20]=2185, -- Chocolate bomb
   [9]=2277, -- Fruit batta
  [10]=2255, -- Toad batta
  [11]=2253, -- Worm batta
  [12]=2281, -- Vegetable batta
  [13]=2259, -- Cheese+tom batta
   [3]=2217, -- Toad crunchies
   [4]=2213, -- Spicy crunchies
   [5]=2205, -- Worm crunchies
   [6]=2209, -- Chocchip crunchies
   [1]=2084, -- Fruit Blast
   [2]=2048, -- Pineapple Punch
   [7]=2054, -- Wizard Blizzard
   [8]=2080, -- Short Green Guy
  [15]=2092, -- Drunk Dragon
  [17]=2074, -- Chocolate Saturday
  [18]=2064, -- Blurberry Special
}

local function translateTaskItemId(taskId)
  return TASK_TO_ITEM[taskId]
end

-- =========================
-- Bank helpers
-- =========================
local function bankEnsureOpen()
  BANK:Open()
  Slib:SleepUntil(function() return BANK:IsOpen() or BANK:IsPINOpen() end, 30, 500)
  if BANK:IsPINOpen() then
    BANK:EnterPIN(0,0,0,0)
    Slib:SleepUntil(function() return BANK:IsOpen() end, 6, 500)
  end
  return BANK:IsOpen()
end

local function bankWithdraw(itemId)
  if not bankEnsureOpen() then log("[BANK] open failed"); return false end
  BANK:Withdraw(itemId)                 -- assumes default qty=1 in your BANK lib
  API.RandomSleep2(2000,100,150)
  API.KeyboardPress2(CFG.KEYS.ESC, 40, 60)
  local ok = BANK:InventoryContains(itemId)
  log(ok and "[BANK] item present" or "[BANK] item missing")
  return ok
end

local function bankMetrics()
  if not bankEnsureOpen() then return end

  local okAll = true
  for _, ia in ipairs(ItemsAndAmounts) do
    if BANK:GetItemAmount(ia[1]) < ia[2] then okAll = false end
  end

  local function logBankItem(id)
  if BANK:InventoryContains(id) then
    local amt = BANK:InventoryGetItemAmount(id) or 0
    local rt  = API.ScriptRuntime()
  end
end

logBankItem(9470)
logBankItem(9472)
logBankItem(9475)
logBankItem(9469)
logBankItem(2998)
logBankItem(3000)
logBankItem(987)
logBankItem(985)
logBankItem(1621)
logBankItem(1617)

for _, ia in ipairs(ItemsAndAmounts) do
  logBankItem(ia[1])  
end

  -- Deposit all (bank interface button: 517,39)
  API.DoAction_Interface(0xffffffff,0xffffffff,1,517,39,-1,API.OFF_ACT_GeneralInterface_route)
  log("[BANK] deposit all")

  if not okAll then
    log("[BANK] Missing stock, stopping")
    API.Write_LoopyLoop(false)
  end
end

-- =========================
-- Task / token
-- =========================
local function hasActiveTask()
  return API.GetVarbitValue(CFG.VARBIT.HAS_TASK) == 1
     and API.GetVarbitValue(CFG.VARBIT.TASK_ID)   ~= 0
     and API.GetVarbitValue(CFG.VARBIT.TASK_GIVER)~= 0
end

local function requestTask(kind)
  if hasActiveTask() then return true end

  local route = (kind == "easy") and API.OFF_ACT_InteractNPC_route2
                                 or API.OFF_ACT_InteractNPC_route3
  taskDuration = (kind == "easy") and 6*60 or 11*60
  taskType     = (kind == "easy") and "easy" or "hard"

  log("[TASK] requesting "..taskType.." task")
  local ok = API.DoAction_NPC(0x29, route, {CFG.NPC.GIANNE_JNR}, 20)
  if not ok then
    log("[TASK] interact failed or already assigned")
    return API.GetVarbitValue(CFG.VARBIT.HAS_TASK) == 1
  end

  API.RandomSleep2(600,100,100)

  if API.ReadPlayerMovin2() then
    while API.Read_LoopyLoop() and API.ReadPlayerMovin2() do
      if not API.Read_LoopyLoop() then return false end
      if isDialogueOpen() then log("[TASK] dialogue open"); break end
      API.RandomSleep2(600,100,100)
    end
  else
    log("[TASK] player not moving (maybe token state)")
  end

  if isDialogueOpen() then
    taskStartTime = API.ScriptRuntime()
    log(string.format("[TASK] timer started (%d min)", taskDuration/60))
  end

  log(string.format("[TASK] TaskID:%s Giver:%s",
      tostring(API.GetVarbitValue(CFG.VARBIT.TASK_ID)),
      tostring(API.GetVarbitValue(CFG.VARBIT.TASK_GIVER))))
  return true
end

local function checkTaskTimer()
  if taskStartTime <= 0 then return false end

  local elapsed   = API.ScriptRuntime() - taskStartTime
  local remaining = taskDuration - elapsed
  if remaining <= 0 then
    log("[TASK TIMER] expired")
    taskStartTime, lastTimerDisplay = 0, 0
    return false
  end

  if API.GetVarbitValue(CFG.VARBIT.HAS_TASK) == 1 then
    local mins = math.floor(remaining / 60)
    local secs = math.floor(remaining % 60)
    local now  = math.floor(remaining)
    if lastTimerDisplay == 0 or (lastTimerDisplay - now) >= 30 then
      log(string.format("[TASK TIMER] %02d:%02d", mins, secs))
      lastTimerDisplay = now
    end
    return true
  else
    log("[TASK TIMER] completed")
    taskStartTime, lastTimerDisplay = 0, 0
    return false
  end
end

local function chatHasTokenWord()
  return API.Dialog_compare_sayd and API.Dialog_compare_sayd("token") == true
end

local function tokenHandler()
  API.RandomSleep2(1000,1000,100)
  API.KeyboardPress2(CFG.KEYS.SPACE, 40, 60)
  API.RandomSleep2(1500,1000,200)
  API.KeyboardPress2(CFG.KEYS.K2, 40, 60)
  API.RandomSleep2(1500,1000,200)
  API.KeyboardPress2(CFG.KEYS.SPACE, 40, 60)
  API.RandomSleep2(1500,1000,200)

  local t0, timeout = API.ScriptRuntime(), 50
  while API.Read_LoopyLoop() and BANK:InventoryContains(9474) do
    API.DoAction_Inventory1(9474, 0, 3, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(7500,2000,1000)
    if API.ScriptRuntime() - t0 > timeout then
      log("[TOKEN] timeout consuming")
      break
    end
  end

  if BANK:InventoryContains(9474) then
    log("[TOKEN] still in inventory -> stopping")
    API.Write_LoopyLoop(false)
  else
    log("[TOKEN] consumed")
  end
end

-- =========================
-- Giver detection / route
-- =========================
local function updateGiverFlags()
  local giver = API.GetVarbitValue(CFG.VARBIT.TASK_GIVER)
  if giver == CFG.GIVERS.DAERKIN then
    log("[TASK] Captain Daerkin")
    Scarftask, Daerkin, Ninto = true, true, false
  elseif giver == CFG.GIVERS.NINTO then
    log("[TASK] Captain Ninto")
    Scarftask, Ninto, Daerkin = true, true, false
  else
    log("[TASK] no scarf task")
    Scarftask, Ninto, Daerkin = false, false, false
  end
end

-- =========================
-- Routes
-- =========================
local function doNinto()
  --Stats:inc("tasks_accepted")
  LODESTONES.TAVERLEY.Teleport()
  Slib:MoveTo(2883+math.random(-2,2), 3458+math.random(-2,2), 0)

  if not area(2879,2887,3455,3462) then API.Write_LoopyLoop(false); return end
  Interact:Object("Cave","Enter",10)
  API.RandomSleep2(3000,100,110)

  Slib:MoveTo(2866, 9876, 0)
  local ok = API.DoAction_NPC(0x2c, API.OFF_ACT_InteractNPC_route, {4594}, 50)
  if ok then
    API.RandomSleep2(6000,100,110)
    if isDialogueOpen() then
      API.RandomSleep2(2000,100,100)
      API.KeyboardPress2(CFG.KEYS.SPACE, 40, 60)
      API.RandomSleep2(1500,100,200)
      API.KeyboardPress2(CFG.KEYS.SPACE, 40, 60)
      API.RandomSleep2(1500,100,200)
      API.KeyboardPress2(CFG.KEYS.ESC, 40, 60)
      bankaction = false
    else
      log("[NINTO] dialogue failed"); API.Write_LoopyLoop(false); return
    end
  else
    log("[NINTO] interact failed"); API.Write_LoopyLoop(false); return
  end
  Ninto=false; TaskState_Finished=true; Scarftask=false; 
  metrics.task("task_completed", "Ninto", API.GetVarbitValue(CFG.VARBIT.TASK_ID), true, false, API.ScriptRuntime())

end

local function doDaerkin()
  --Stats:inc("tasks_accepted")
  LODESTONES.AL_KHARID.Teleport()
  Slib:MoveTo(3317+math.random(-2,2), 3161+math.random(-2,2), 0)

  local ok = Interact:NPC(CFG.NPC.DAERKIN, "Talk-to", 20)
  if ok then
    API.RandomSleep2(6000,100,110)
    if isDialogueOpen() then
      API.RandomSleep2(2000,100,100)
      API.KeyboardPress2(CFG.KEYS.SPACE, 40, 60)
      API.RandomSleep2(1500,100,200)
      API.KeyboardPress2(CFG.KEYS.SPACE, 40, 60)
      API.RandomSleep2(1500,100,200)
      API.KeyboardPress2(CFG.KEYS.ESC, 40, 60)
      bankaction = false
    else
      log("[DAERKIN] dialogue failed");  API.Write_LoopyLoop(false); return
    end
  else
    log("[DAERKIN] interact failed");  API.Write_LoopyLoop(false); return
  end

  Daerkin=false; TaskState_Finished=true; Scarftask=false; 
  metrics.task("task_completed", "Daerkin", API.GetVarbitValue(CFG.VARBIT.TASK_ID), true, false, API.ScriptRuntime())
end

-- =========================
-- Return to base
-- =========================
local function returnToBase_1()
  -- requires equipment tab visible? you had a guard here—keep it if needed
  API.DoAction_Interface(0xffffffff,0x9b80,3,1464,15,12,API.OFF_ACT_GeneralInterface_route)
  API.RandomSleep2(4000,1000,2000)

  Slib:MoveTo(3184+math.random(-2,2), 3508+math.random(-2,2), 0)
  if not area(3179,3189,3506,3513) then  API.Write_LoopyLoop(false); return end

  Interact:Object(CFG.OBJ.SPIRIT_TREE, "Teleport", 10)
  API.RandomSleep2(2000,1000,2000)
  API.RandomSleep2(2000,1000,2000)

  if not area(2541,2542,3165,3173) then  API.Write_LoopyLoop(false); return end
  Interact:Object(CFG.OBJ.SPIRIT_TREE, "Teleport", 10)
  --increased to 4 seconds, since error on 3 secs loading time when ever running multiple accounts. 
    API.RandomSleep2(2000,1000,2000)
    print("sleeping")
    API.RandomSleep2(2000,1000,2000)
    print("sleeping")

    if isTeleportOpen() then
      API.DoAction_Interface(0xffffffff,0xffffffff,1,1145,13,-1,API.OFF_ACT_GeneralInterface_route)
    else
      Interact:Object(CFG.OBJ.SPIRIT_TREE, "Teleport", 10)
      if isTeleportOpen() then
        print("retry tree")
      API.DoAction_Interface(0xffffffff,0xffffffff,1,1145,13,-1,API.OFF_ACT_GeneralInterface_route)
    else
      log("[RETURN] teleport ui not open");  API.Write_LoopyLoop(false)
    end
  end 
end

local function returnToBase_2()
  API.RandomSleep2(5000,2000,100)
  Slib:MoveTo(2465,3475,0)
  Slib:MoveTo(2466,3489,0)
  API.RandomSleep2(2000,100,100)

  if area(2464,2467,3485,3490) then
    Interact:Object(CFG.OBJ.TREE_DOOR, "Open", 10)
    log("[TASK] open tree door")
    API.RandomSleep2(5000,100,100)
    interactionsucces_5 = true
  else
     API.Write_LoopyLoop(false); interactionsucces_5=false; return
  end

  if area(2465,2466,3493,3496) then
    API.DoAction_Object1(0x34, API.OFF_ACT_GeneralObject_route0, {CFG.OBJ.LADDER}, 50)
    log("[TASK] climb ladder")
    API.RandomSleep2(2500,300,200)
  else
     API.Write_LoopyLoop(false); return
  end

  Slib:MoveTo(2442,3488,1)
  log("[TASK] at bank")
end

-- =========================
-- Reject task dialog macro
-- =========================
local function rejectTask()
  API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route3, {CFG.NPC.GIANNE_JNR}, 20)
  local K = CFG.KEYS
  local function tap(k) API.KeyboardPress2(k,40,60); API.RandomSleep2(1500,100,200) end

  tap(K.SPACE); tap(K.SPACE); tap(K.SPACE); tap(K.SPACE); tap(K.SPACE); tap(K.SPACE)
  tap(K.K1);    log("Press 1")
  tap(K.SPACE); tap(K.SPACE)
  log("Press 2"); tap(K.K2)
  tap(K.SPACE); tap(K.SPACE)
  -- arrive lobby after macro
end

-- =========================
-- Lobby wait helper
-- =========================
local function countdownOver()
  local now = API.SystemTime()
  local diff = now - StartingTime
  local remaining = TargetDelay - diff
  if remaining > 0 then
    local s = math.floor(remaining/1000)
    local m = math.floor(s/60)
    log(string.format("Time left: %02d:%02d", m, s%60))
  else
    log("Time left: 00:00")
  end
  return diff >= TargetDelay
end

-- =========================
-- Main loop
-- =========================
--Stats:send("LoopStart")
while API.Read_LoopyLoop() do

  watchywatch = watchywatch + 1

  if API.GetGameState2() == 3 then
    -- cache guard
    if not API.CacheEnabled or not API.IsCacheLoaded() then
      Slib:Error("Cache not enabled/loaded. Halting.")
      API.Write_LoopyLoop(false)
      break
    end

    if not ReadyToRequest then
      -- we are executing a task flow
      if Scarftask then
        local taskId   = API.GetVarbitValue(CFG.VARBIT.TASK_ID)
        local itemId   = translateTaskItemId(taskId)
        if not itemId then
          log("[TASK] unknown recipe id "..tostring(taskId)); API.Write_LoopyLoop(false); break
        end

        log("[TASK] withdrawing item "..itemId)
        if not bankaction then
          if bankWithdraw(itemId) then
            bankaction = true
          else
            log("[BANK] withdraw failed"); API.Write_LoopyLoop(false); break
          end
        end

        if Ninto then
          log("[TASK] Ninto route")
          doNinto()
        elseif Daerkin then
          log("[TASK] Daerkin route")
          doDaerkin()
        end
      end

      if TaskState_Finished then
        log("[TASK] returning to base")
        returnToBase_1()
        returnToBase_2()
        if interactionsucces_5 then
          log("[TASK] bank metrics")
          bankMetrics()
        else
          API.Write_LoopyLoop(false); break
        end
        TaskState_Finished = false
        ReadyToRequest     = true
      end

    else
      -- We are ready to request / evaluate tasks
      if not hasActiveTask() then
        requestTask(taskType)
        if chatHasTokenWord() then
          log("Token(chatbox) found")
          tokenHandler()
        end
      else
        checkTaskTimer()
        updateGiverFlags()
        if not Scarftask then
          rejectTask()
          log("rejecting")
          API.RandomSleep2(2000,100,200)
          StartingTime = API.SystemTime()
          -- enter lobby
          API.DoAction_Interface(0xffffffff,0xffffffff,1,1477,98,1,API.OFF_ACT_GeneralInterface_route)
          API.RandomSleep2(5000,1000,1020)
          API.DoAction_Interface(0x24,0xffffffff,1,1433,68,-1,API.OFF_ACT_GeneralInterface_route)
          API.RandomSleep2(2000,1000,1020)
          log("[TASK] Enter Lobby")
        else
          log("[TASK] progressing to scarf task")
          ReadyToRequest = false
        end
      end
    end

  elseif API.GetGameState2() == 2 then
    -- In lobby: wait randomized cooldown then exit lobby
    if countdownOver() then
      log("Countdown over")
      API.DoAction_Interface(0xffffffff,0xffffffff,1,906,81,-1,API.OFF_ACT_GeneralInterface_route)
      log("[TASK] Exit Lobby")
      API.RandomSleep2(8000,100,200)
      if watchywatch == 2 then break end
    end
    API.RandomSleep2(1000,100,200)
end
end
