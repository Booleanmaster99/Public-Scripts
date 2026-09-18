--[[
   Author: Booleanmaster9000
]]

local API = require("api")

local ok, FarmingData = pcall(require, "FarmingData")
if not ok or type(FarmingData) ~= "table" then
    print("[FarmingPatches] Failed to load FarmingData.lua: " .. tostring(FarmingData))
    print("[FarmingPatches] Make sure FarmingData.lua sits next to this script in Lua_Scripts.")
    return
end

local STATES = FarmingData.states or {}
local ENUMS = FarmingData.enums or {}
local CROPS_BY_CONFIG = {}   
for _, t in ipairs(FarmingData.patchTypes or {}) do
    if t.crops then
        local cfg = tostring(t.config)
        local map = {}
        for valueStr, seedIdx in pairs(t.crops) do
            local seed = t.seeds[seedIdx + 1]  
            if seed then map[valueStr] = seed.plant end
        end
        CROPS_BY_CONFIG[cfg] = map
    end
end


local function decode(config, value)
    local cfg, val = tostring(config), tostring(value)
    local enumMap = ENUMS[cfg]
    if not enumMap then return "Unknown", "" end
    local code = enumMap[val]
    local state = code and STATES[tostring(code)] or "Empty"
    local crop = (CROPS_BY_CONFIG[cfg] and CROPS_BY_CONFIG[cfg][val]) or ""
    return state, crop
end

local READY = { Harvestable = true, ["Fully grown"] = true }
local ATTENTION = { Diseased = true, Dead = true, ["Needs watering"] = true, Weeds = true }

local JUJU_FARMING_BUFF_ID = 33234   

local function secateursActive()
    local okE, eq = pcall(function() return Equipment:Contains("Magic secateurs") end)
    local okI, inv = pcall(function() return Inventory:Contains("Magic secateurs") end)
    return (okE and eq) or (okI and inv)
end

local function jujuFarmingActive()
    local okB, bar = pcall(API.Buffbar_GetIDstatus, JUJU_FARMING_BUFF_ID, false)
    return okB and bar and (bar.found or (bar.id and bar.id ~= 0))
end

local POLL_MS = 3000
local lastPoll = 0

local decoded = {}
local showEmpty = false

local function pollAll()
    local list = {}
    for _, t in ipairs(FarmingData.patchTypes or {}) do
        for _, p in ipairs(t.patches or {}) do
            local okV, val = pcall(API.GetVarbitValue, p.varbit)
            local value = okV and val or 0
            local state, crop = decode(t.config, value)
            list[#list + 1] = {
                typeName = t.name, location = p.location, varbit = p.varbit,
                state = state, crop = crop,
                ready = READY[state] == true, attention = ATTENTION[state] == true,
            }
        end
    end
    return list
end

local COLOR = {
    good = { 0.35, 0.85, 0.35 }, bad = { 1.0, 0.38, 0.38 }, warn = { 1.0, 0.75, 0.2 },
    info = { 0.55, 0.78, 1.0 }, dim = { 0.6, 0.6, 0.6 },
}

local function colored(c, text)
    local col = COLOR[c] or COLOR.dim
    ImGui.TextColored(col[1], col[2], col[3], 1, text)
end

local function tableFlags()
    local okF, f = pcall(function() return ImGuiTableFlags.Borders + ImGuiTableFlags.RowBg end)
    return okF and f or 0
end

local function stateColor(p)
    if p.ready then return "good" end
    if p.attention then return "bad" end
    if p.state == "Empty" then return "dim" end
    return nil
end

local function stateLabel(p)
    local label = p.crop ~= "" and (p.state .. "  (" .. p.crop .. ")") or p.state
    if p.ready then label = "\226\152\133 " .. label end   
    return label
end

local function drawPatchTable(id, patches)
    if #patches == 0 then
        ImGui.TextDisabled("No patches of this type in the catalog.")
        return
    end
    if ImGui.BeginTable(id, 3, tableFlags()) then
        ImGui.TableSetupColumn("Location")
        ImGui.TableSetupColumn("State")
        ImGui.TableSetupColumn("Varbit")
        ImGui.TableHeadersRow()
        for _, p in ipairs(patches) do
            if p.state ~= "Empty" or showEmpty then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                ImGui.Text(p.location)
                ImGui.TableSetColumnIndex(1)
                colored(stateColor(p), stateLabel(p))
                ImGui.TableSetColumnIndex(2)
                ImGui.TextDisabled(tostring(p.varbit))
            end
        end
        ImGui.EndTable()
    end
end

local function drawReadyTable(readyPatches)
    if #readyPatches == 0 then
        ImGui.TextDisabled("Nothing ready right now.")
        return
    end
    if ImGui.BeginTable("ready_table", 3, tableFlags()) then
        ImGui.TableSetupColumn("Type")
        ImGui.TableSetupColumn("Location")
        ImGui.TableSetupColumn("Crop")
        ImGui.TableHeadersRow()
        for _, p in ipairs(readyPatches) do
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0)
            ImGui.Text(p.typeName)
            ImGui.TableSetColumnIndex(1)
            colored("good", p.location)
            ImGui.TableSetColumnIndex(2)
            ImGui.Text(p.crop ~= "" and p.crop or p.state)
        end
        ImGui.EndTable()
    end
end

local function drawGuiContent()
    local totalReady, totalAttn = 0, 0
    local byType, readyPatches = {}, {}
    for _, t in ipairs(FarmingData.patchTypes or {}) do byType[t.name] = {} end
    for _, p in ipairs(decoded) do
        if byType[p.typeName] then table.insert(byType[p.typeName], p) end
        if p.ready then
            totalReady = totalReady + 1
            readyPatches[#readyPatches + 1] = p
        elseif p.attention then
            totalAttn = totalAttn + 1
        end
    end

    ImGui.Text(string.format("Tracking %d patches", #decoded))
    ImGui.SameLine()
    colored(totalReady > 0 and "good" or "dim", string.format("  %d ready", totalReady))
    ImGui.SameLine()
    colored(totalAttn > 0 and "warn" or "dim", string.format("  %d need attention", totalAttn))

    ImGui.Text("Boosts:")
    ImGui.SameLine()
    colored(secateursActive() and "good" or "dim", secateursActive() and "Secateurs ON" or "Secateurs off")
    ImGui.SameLine()
    colored(jujuFarmingActive() and "good" or "dim", "  " .. (jujuFarmingActive() and "Juju pot ON" or "Juju pot off"))

    local changed, value = ImGui.Checkbox("Show empty patches", showEmpty)
    if changed then showEmpty = value end

    ImGui.Separator()

    if ImGui.BeginTabBar("farming_patch_tabs") then
        if ImGui.BeginTabItem("\226\152\133 Ready now") then
            drawReadyTable(readyPatches)
            ImGui.EndTabItem()
        end
        for _, t in ipairs(FarmingData.patchTypes or {}) do
            local patches = byType[t.name] or {}
            local tReady, tAttn = 0, 0
            for _, p in ipairs(patches) do
                if p.ready then tReady = tReady + 1 elseif p.attention then tAttn = tAttn + 1 end
            end
            local label = t.name
            if tReady > 0 then label = label .. " (" .. tReady .. ")" end
            if ImGui.BeginTabItem(label) then
                if tAttn > 0 then colored("warn", tAttn .. " need attention"); end
                drawPatchTable(t.config .. "_table", patches)
                ImGui.EndTabItem()
            end
        end
        ImGui.EndTabBar()
    end
end

local guiTopY = nil
if type(DrawImGui) == "function" then
    -- callbacks survive a script restart: drop any left over from earlier runs (as aio mining/
    -- VaultExecutor do)
    if type(ClearRender) == "function" then pcall(ClearRender) end
    DrawImGui(function()
        pcall(function() ImGui.SetNextWindowSize(480, 480, ImGuiCond.FirstUseEver) end)
        ImGui.Begin("Farming Patches")
        -- If the callback runs more than once in a frame, Begin() on the same window appends below the
        -- first copy (repeated header). Content already drawn = cursor not at the top.
        local okY, y = pcall(ImGui.GetCursorPosY)
        if okY and type(y) == "number" then
            if not guiTopY or y < guiTopY then guiTopY = y end
            if y > guiTopY + 4 then
                ImGui.End()
                return
            end
        end
        local okD, err = pcall(drawGuiContent)
        if not okD then colored("bad", "gui error: " .. tostring(err)) end
        ImGui.End()
    end)
else
    print("[FarmingPatches] DrawImGui not available in this client build - GUI will not render.")
end

-- ---- main loop: just keeps the varbit poll fresh; the GUI redraws itself via DrawImGui ----
API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do
    local now = API.SystemTime() or 0
    if now - lastPoll >= POLL_MS or lastPoll == 0 then
        local okP, polled = pcall(pollAll)
        if okP then decoded = polled end
        lastPoll = now
    end
    API.RandomSleep2(200, 50, 50)
end
