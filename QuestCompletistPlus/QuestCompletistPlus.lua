-- Quest Completist+ 1.2.0.
-- Writes a quest's level before its name, "[12] Name", in three places:
--   1. the list Quest Completist shows when its map icon is hovered,
--   2. an NPC's quest selection (the gossip window, and the quest greeting window),
--   3. the window of a single quest (accept, not finished yet, hand in).
-- The level is Quest Completist's own (qcQuestDatabase), the game's only for a quest it does not know.
-- With DialogKey the lines read "1. [12] Name"; the option "Hide DialogKey's numbers" (off by default) takes its
-- "1. " off the selection windows' lines, and its keys still work: they pick by position, not text.
-- The quest window's title is drawn in the standard font, the quest text's own, unless the option "Quest title
-- in the standard font" is unticked.
-- Each option is one checkbox in the game's AddOns settings (Blizzard_Settings_Shared/Blizzard_Settings.lua
-- 134, 154, 174, 388, as its Blizzard_ImplementationReadme.lua 86-96 shows).
--
-- Written against WoW Forever 1.60.1.70938 (Interface 16001). Every game function, event, and widget method
-- below was checked against that build (the Zephras Forever API Reference, lookup/):
--   json/functions.jsonl, status both: issecretvalue, GetBuildInfo, GetServerTime,
--     C_QuestLog.GetQuestDifficultyLevel, C_QuestLog.GetTitleForQuestID;
--     C_GossipInfo.GetAvailableQuests / GetActiveQuests give the info tables the gossip buttons are set up
--     with (fields title, questLevel, isTrivial, isIgnored, questID: raw/docs/GossipInfoDocumentation.lua).
--   json/functions.jsonl, status runtime_only (undocumented-on-16001; arguments as the shipped calls in
--     Blizzard_UIPanels_Game/Mainline/QuestFrame.lua 212, 347, 362, 393, 396 and QuestInfo.lua 40, 143):
--     hooksecurefunc, CreateFrame, GetQuestID, GetTitleText, GetActiveTitle, GetAvailableTitle,
--     GetActiveQuestID, GetAvailableQuestInfo.
--   events/PLAYER_LOGIN.md, events/ADDON_ACTION_BLOCKED.md, events/ADDON_ACTION_FORBIDDEN.md.
--   widgets/GameTooltip.md (NumLines, Show, GetOwner), widgets/FontString.md (GetText, SetText, IsShown, GetFont, SetFont),
--     widgets/Button.md (GetText, SetText, GetTextHeight), widgets/Frame.md (HookScript, SetHeight, GetID),
--     widgets/Texture.md (GetHeight).
-- The game's own Lua, hooked after it runs and never replaced (Interface/AddOns/ of that build):
--   Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua 27-58, 63-93 (quest and option button Setup),
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.lua 205-213, 319-420 (progress page, greeting page),
--   Blizzard_UIPanels_Game/Mainline/QuestInfo.lua 28, 140-162 (the quest's title),
--   Blizzard_SharedXMLBase/Pools.lua 166 (EnumerateActive).
-- Other addons, read from the installed copies: QuestCompletist 114.5 (qcMapPins.lua 255-401,
--   qcTooltips.lua 150-250, Forever/qcQuestData.lua), DialogKey_Numy v1.2.62 (main.lua 225-314, 775-793).

local ADDON = ...
local VERSION = "1.2.0"
local SAMPLES, MISMATCHES = 20, 500
local TITLE_SMALLER = 2

local DB

--[[ What happened, for the saved file ]]--

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

local function Place(name)
	local place = DB.places[name]
	if not place then
		place = {wrote = 0, skipped = {}, samples = {}}
		DB.places[name] = place
	end
	return place
end

local function Wrote(name, questId, level, text)
	local place = Place(name)
	place.wrote = place.wrote + 1
	local samples = place.samples
	samples[#samples + 1] = {GetServerTime(), questId, level, text}
	if #samples > SAMPLES then table.remove(samples, 1) end
end

local function Skipped(name, why)
	local skipped = Place(name).skipped
	skipped[why] = (skipped[why] or 0) + 1
end

--[[ The level ]]--

-- Quest Completist's quest table, or nil: read by name, checked once (a row is {name, level, ...}).
local qcChecked, qcRows
local function QuestRows()
	if not qcChecked then
		qcChecked = true
		local rows = rawget(_G, "qcQuestDatabase")
		local state = "missing"
		if type(rows) == "table" then
			local _, row = next(rows)
			if type(row) == "table" and type(row[1]) == "string" and type(row[2]) == "number" then
				qcRows, state = rows, "ok"
			else
				state = "unfit"
			end
		end
		DB.load.questCompletistLevels = state
	end
	return qcRows
end

local function StoredLevel(questId)
	local rows = QuestRows()
	local row = rows and rows[questId]
	local level = type(row) == "table" and row[2]
	if type(level) == "number" and level > 0 then return level end
end

-- The level to show: Quest Completist's, else the game's (gameLevel, already read by the caller). A quest both
-- know with different levels is noted.
local function LevelOf(questId, gameLevel)
	if Secret(questId) or type(questId) ~= "number" or questId == 0 then return nil end
	if Secret(gameLevel) or type(gameLevel) ~= "number" or gameLevel <= 0 then gameLevel = nil end
	local stored = StoredLevel(questId)
	if stored and gameLevel and stored ~= gameLevel and not DB.mismatch[questId] and DB.mismatchCount < MISMATCHES then
		DB.mismatch[questId] = {stored, gameLevel}
		DB.mismatchCount = DB.mismatchCount + 1
	end
	return stored or gameLevel
end

local function GameLevel(questId)
	if Secret(questId) or type(questId) ~= "number" or questId == 0 then return nil end
	return C_QuestLog.GetQuestDifficultyLevel(questId)
end

local function Tag(level)
	return string.format("[%d] ", level)
end

-- `text` with `tag` put right before `title` inside it, or before the whole text when the title is not found.
local function AddTag(text, title, tag)
	local at = type(title) == "string" and title ~= "" and string.find(text, title, 1, true)
	if not at then return tag .. text end
	return string.sub(text, 1, at - 1) .. tag .. string.sub(text, at)
end

-- DialogKey's number, "1. ", off the front of a text.
local function WithoutNumber(text)
	local number = string.match(text, "^%d%. ")
	if number then return string.sub(text, #number + 1), true end
	return text, false
end

--[[ 1. Quest Completist's map icon list ]]--

-- The quests of the hovered icon: {[questId] = true}, or nil when the tooltip's owner is not a quest icon.
local function PinQuests(pin)
	local data = type(pin) == "table" and pin.PinData
	if type(data) ~= "table" then return nil end
	local quests = {}
	local members = type(data.stack) == "table" and data.stack or {data}
	for _, member in ipairs(members) do
		if type(member) == "table" then
			if type(member[6]) == "table" then
				for _, questId in ipairs(member[6]) do quests[questId] = true end
			end
			if type(member.allQuests) == "table" then
				for _, questId in ipairs(member.allQuests) do quests[questId] = true end
			end
		end
	end
	return quests
end

-- The icon's quest a line is about: by the grey ID on its right, else by its name when every quest of the icon
-- with that name has one level. Returns the quest and its level.
local function LineQuest(quests, name, rightText)
	local rows = QuestRows()
	if not rows then return nil end
	local id = type(rightText) == "string" and tonumber(string.match(rightText, "^|cff808080(%d+)|r$"))
	if id and quests[id] then
		return id, StoredLevel(id)
	end
	local found, level
	for questId in pairs(quests) do
		local row = rows[questId]
		local known = type(row) == "table" and row[1]
		if known ~= name then
			known = C_QuestLog.GetTitleForQuestID(questId)
			if Secret(known) then known = nil end
		end
		if known == name then
			local own = StoredLevel(questId)
			if found and own ~= level then return nil end
			found, level = questId, own
		end
	end
	return found, level
end

local mapWritten = setmetatable({}, {__mode = "k"})
local mapBusy

local function MapTooltipShown(tooltip)
	if mapBusy then return end
	local quests = PinQuests(tooltip:GetOwner())
	if not quests then return end
	local changed = false
	for line = 1, tooltip:NumLines() do
		local left, right = _G["qcMapTooltipTextLeft" .. line], _G["qcMapTooltipTextRight" .. line]
		local text = left and left:GetText()
		if type(text) == "string" and not Secret(text) and mapWritten[left] ~= text then
			-- A quest's line: four spaces, perhaps a type icon, the name in a colour (qcMapPins.lua 260-270).
			local before, colour, rest = string.match(text, "^(    .-)(|cff%x%x%x%x%x%x)(.*)$")
			local name = rest and string.match(rest, "^(.-)|r")
			if name and name ~= "" and string.sub(name, 1, 1) ~= "[" then
				local rightText = right and right:IsShown() and right:GetText()
				if Secret(rightText) then rightText = nil end
				local questId, level = LineQuest(quests, name, rightText)
				if questId and level then
					local new = before .. colour .. Tag(level) .. rest
					left:SetText(new)
					mapWritten[left] = new
					changed = true
					Wrote("map", questId, level, new)
				elseif questId then
					Skipped("map", "no level")
				else
					Skipped("map", "not matched")
				end
			end
		end
	end
	if changed then
		-- Once more, so the tooltip takes the width of its longer lines.
		mapBusy = true
		tooltip:Show()
		mapBusy = false
	end
end

--[[ 2a. The gossip window ]]--

-- The quest's tag, kept on its info table (a new table each time the game builds the list); false for none.
local function GossipTag(info)
	local tag = info.QuestCompletistPlus_tag
	if tag == nil then
		tag = false
		local questId, title = info.questID, info.title
		if Secret(questId) or Secret(title) or type(title) ~= "string" then
			Skipped("gossip", "secret")
		else
			local level = LevelOf(questId, info.questLevel)
			if level then
				tag = Tag(level)
				Wrote("gossip", questId, level, tag .. title)
			else
				Skipped("gossip", "no level")
			end
		end
		info.QuestCompletistPlus_tag = tag
	end
	return tag or nil
end

-- After the game set a button up. A button DialogKey numbers keeps its text in DialogKeyNumy_Text (on the info
-- table and on the button) and puts it back when the button's text changes, so that kept text is what gets
-- the number taken off and the level put in; DialogKey then holds our text in place.
local function GossipButtonSetUp(button, info, isQuest)
	if type(info) ~= "table" then return end
	local tag = isQuest and GossipTag(info) or nil
	local kept = info.DialogKeyNumy_Text
	if type(kept) == "string" and kept ~= "" then
		if not info.QuestCompletistPlus_done then
			info.QuestCompletistPlus_done = true
			local text, numbered = kept, false
			if DB.hideDialogKeyNumbers then text, numbered = WithoutNumber(kept) end
			if tag then text = AddTag(text, info.title, tag) end
			info.DialogKeyNumy_Text = text
			if numbered then DB.dialogKey.gossip = DB.dialogKey.gossip + 1 end
		end
		local text = info.DialogKeyNumy_Text
		local onButton = button.DialogKeyNumy_Text
		if type(onButton) == "string" and onButton ~= "" then button.DialogKeyNumy_Text = text end
		local shown = button:GetText()
		if not Secret(shown) and shown ~= text then button:SetTextAndResize(text) end
		return
	end
	if tag then
		-- The game's own title routine: it colours a low-level or ignored quest and sizes the button.
		button:UpdateTitleForQuest(info.questID, tag .. info.title, info.isIgnored, info.isTrivial)
	end
end

--[[ 2b. The quest greeting window ]]--

local greetingWanted = setmetatable({}, {__mode = "k"})
local greetingHooked = setmetatable({}, {__mode = "k"})
local greetingBusy

-- DialogKey numbers these buttons a frame after the game fills them: the number comes off again.
local function GreetingTextSet(button, text)
	if greetingBusy or not DB.hideDialogKeyNumbers then return end
	local wanted = greetingWanted[button]
	if not wanted or Secret(text) or type(text) ~= "string" or text == wanted then return end
	local rest, numbered = WithoutNumber(text)
	if numbered and rest == wanted then
		greetingBusy = true
		button:SetText(wanted)
		greetingBusy = false
		DB.dialogKey.greeting = DB.dialogKey.greeting + 1
	end
end

local function GreetingFilled()
	local panel = QuestFrameGreetingPanel
	local pool = panel and panel.titleButtonPool
	if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return end
	for button in pool:EnumerateActive() do
		local index = button:GetID()
		local questId, title
		if button.isActive == 1 then
			questId, title = GetActiveQuestID(index), (GetActiveTitle(index))
		else
			questId, title = select(5, GetAvailableQuestInfo(index)), GetAvailableTitle(index)
		end
		local text = button:GetText()
		if Secret(text) or type(text) ~= "string" then
			greetingWanted[button] = nil
		else
			local wanted = text
			if Secret(questId) or Secret(title) then
				Skipped("greeting", "secret")
			else
				local level = LevelOf(questId, GameLevel(questId))
				if not level then
					Skipped("greeting", "no level")
				elseif not string.find(text, Tag(level), 1, true) then
					wanted = AddTag(text, title, Tag(level))
					Wrote("greeting", questId, level, wanted)
				end
			end
			greetingWanted[button] = wanted
			if wanted ~= text then
				greetingBusy = true
				button:SetText(wanted)
				greetingBusy = false
				-- The game's own height for these buttons (QuestFrame.lua 363).
				local iconHeight = button.Icon and button.Icon:GetHeight() or 0
				button:SetHeight(math.max(button:GetTextHeight() + 2, iconHeight))
			end
			if not greetingHooked[button] then
				greetingHooked[button] = true
				hooksecurefunc(button, "SetText", GreetingTextSet)
			end
		end
	end
end

--[[ 3. A single quest's window ]]--

local function QuestTitleWritten(fontString)
	if not fontString then return end
	local questId, title = GetQuestID(), GetTitleText()
	local text = fontString:GetText()
	if Secret(questId) or Secret(title) or Secret(text) then
		Skipped("quest", "secret")
		return
	end
	if type(text) ~= "string" or text == "" then return end
	local level = LevelOf(questId, GameLevel(questId))
	if not level then
		Skipped("quest", "no level")
		return
	end
	local tag = Tag(level)
	if string.find(text, tag, 1, true) then return end
	local new = AddTag(text, title, tag)
	fontString:SetText(new)
	Wrote("quest", questId, level, new)
end

--[[ The quest title's font ]]--

-- The title's own font (QuestTitleFont, FontStyles.xml 42) is ornate for letters and plain for digits and
-- brackets. With the option on, the whole title takes the font of the quest's body text beside it (QuestFont,
-- FontStyles.xml 46), two points under the title's size; colour and shadow stay the game's. Off, or in the
-- quest log's view, the title gets back the font the game gave it.
local titleFonts = {}

local function TitleFont(title, body, standard)
	if not title or type(title.GetFont) ~= "function" or type(title.SetFont) ~= "function" then return end
	local own = titleFonts[title]
	if not own then
		local file, size, flags = title:GetFont()
		if Secret(file) or Secret(size) or Secret(flags) or type(file) ~= "string" or type(size) ~= "number" then return end
		own = {file = file, size = size, flags = flags, now = file}
		titleFonts[title] = own
	end
	local file, size = own.file, own.size
	if standard and body and type(body.GetFont) == "function" then
		local bodyFile = body:GetFont()
		if not Secret(bodyFile) and type(bodyFile) == "string" and size > TITLE_SMALLER then
			file, size = bodyFile, size - TITLE_SMALLER
		end
	end
	if own.now ~= file then
		title:SetFont(file, size, own.flags)
		own.now = file
		DB.titleFont = file
	end
end

--[[ Start ]]--

-- Each hook is made only when what it hooks is there; the saved file says which were made.
local function Hook(name, ok, make)
	if ok then make() end
	DB.load.hooks[name] = ok and true or false
end

local function Start()
	QuestCompletistPlusDB = type(QuestCompletistPlusDB) == "table" and QuestCompletistPlusDB or {}
	DB = QuestCompletistPlusDB
	DB.places = type(DB.places) == "table" and DB.places or {}
	DB.mismatch = type(DB.mismatch) == "table" and DB.mismatch or {}
	DB.mismatchCount = type(DB.mismatchCount) == "number" and DB.mismatchCount or 0
	DB.dialogKey = type(DB.dialogKey) == "table" and DB.dialogKey or {}
	DB.dialogKey.gossip = DB.dialogKey.gossip or 0
	DB.dialogKey.greeting = DB.dialogKey.greeting or 0
	DB.blocked = type(DB.blocked) == "table" and DB.blocked or {}
	local version, build = GetBuildInfo()
	-- 1.0.0 always took DialogKey's numbers off: a save from it keeps that; a new install keeps the numbers.
	if type(DB.hideDialogKeyNumbers) ~= "boolean" then
		DB.hideDialogKeyNumbers = type(DB.load) == "table" and DB.load.version == "1.0.0"
	end
	if type(DB.standardTitleFont) ~= "boolean" then DB.standardTitleFont = true end
	DB.load = {version = VERSION, game = version, build = build, time = GetServerTime(), hooks = {}}
	QuestRows()

	Hook("options", type(Settings) == "table" and type(Settings.RegisterVerticalLayoutCategory) == "function"
			and type(Settings.RegisterAddOnSetting) == "function" and type(Settings.CreateCheckbox) == "function"
			and type(Settings.RegisterAddOnCategory) == "function" and type(Settings.VarType) == "table", function()
		local category = Settings.RegisterVerticalLayoutCategory("Quest Completist+")
		local setting = Settings.RegisterAddOnSetting(category, "QUESTCOMPLETISTPLUS_HIDE_DIALOGKEY_NUMBERS",
			"hideDialogKeyNumbers", DB, Settings.VarType.Boolean, "Hide DialogKey's numbers", false)
		Settings.CreateCheckbox(category, setting,
			"Takes DialogKey's 1. 2. 3. off the lines of an NPC's quest list. Its number keys still work. Shows the next time the list opens.")
		local font = Settings.RegisterAddOnSetting(category, "QUESTCOMPLETISTPLUS_STANDARD_TITLE_FONT",
			"standardTitleFont", DB, Settings.VarType.Boolean, "Quest title in the standard font", true)
		Settings.CreateCheckbox(category, font,
			"Draws a quest's title in the same font as the quest's text, so the level and the name match. Unticked, the title keeps the game's ornate font. Shows the next time a quest opens.")
		Settings.RegisterAddOnCategory(category)
	end)

	local mapTooltip = rawget(_G, "qcMapTooltip")
	Hook("map", type(mapTooltip) == "table" and type(mapTooltip.Show) == "function", function()
		hooksecurefunc(mapTooltip, "Show", MapTooltipShown)
	end)

	local available, active = GossipSharedAvailableQuestButtonMixin, GossipSharedActiveQuestButtonMixin
	Hook("gossipAvailable", type(available) == "table" and type(available.Setup) == "function", function()
		hooksecurefunc(available, "Setup", function(button, info) GossipButtonSetUp(button, info, true) end)
	end)
	Hook("gossipActive", type(active) == "table" and type(active.Setup) == "function", function()
		hooksecurefunc(active, "Setup", function(button, info) GossipButtonSetUp(button, info, true) end)
	end)
	local option = GossipOptionButtonMixin
	Hook("gossipOption", type(option) == "table" and type(option.Setup) == "function", function()
		hooksecurefunc(option, "Setup", function(button, info) GossipButtonSetUp(button, info, false) end)
	end)

	-- The page's script is bound to the function itself (QuestFrame.xml 282), the quest log update calls it by
	-- name (QuestFrame.lua 89): one hook for each way in.
	Hook("greeting", QuestFrameGreetingPanel ~= nil and type(QuestFrameGreetingPanel_OnShow) == "function", function()
		QuestFrameGreetingPanel:HookScript("OnShow", GreetingFilled)
		hooksecurefunc("QuestFrameGreetingPanel_OnShow", GreetingFilled)
	end)

	Hook("questTitle", type(QuestInfo_Display) == "function" and QuestInfoFrame ~= nil, function()
		hooksecurefunc("QuestInfo_Display", function()
			-- The NPC's window only; the quest log's own view of a quest is left as it is.
			local npc = not QuestInfoFrame.questLog
			TitleFont(QuestInfoTitleHeader, QuestInfoDescriptionText, npc and DB.standardTitleFont)
			if npc then QuestTitleWritten(QuestInfoTitleHeader) end
		end)
	end)
	Hook("questProgress", QuestFrameProgressPanel ~= nil, function()
		QuestFrameProgressPanel:HookScript("OnShow", function()
			TitleFont(QuestProgressTitleText, QuestProgressText, DB.standardTitleFont)
			QuestTitleWritten(QuestProgressTitleText)
		end)
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, addon, what)
	if event == "PLAYER_LOGIN" then
		Start()
	elseif DB and not Secret(addon) and not Secret(what) and addon == ADDON and #DB.blocked < SAMPLES then
		DB.blocked[#DB.blocked + 1] = {GetServerTime(), event, what}
	end
end)
