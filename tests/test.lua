-- Runs QuestCompletistPlus.lua outside the game against stand-ins shaped like the code it hooks
-- (QuestCompletist 114.5, DialogKey_Numy v1.2.62, Forever's quest and gossip windows). arg[1] = the Lua file.
local fails = 0
local function check(what, got, want)
	if got ~= want then
		fails = fails + 1
		print("FAIL " .. what .. "\n  got:  " .. tostring(got) .. "\n  want: " .. tostring(want))
	else
		print("ok   " .. what .. " -> " .. tostring(got))
	end
end

-- hooksecurefunc: after the original, both forms.
function hooksecurefunc(a, b, c)
	local owner, name, fn = _G, a, b
	if type(a) == "table" then owner, name, fn = a, b, c end
	local original = owner[name]
	assert(type(original) == "function", "nothing to hook: " .. tostring(name))
	owner[name] = function(...)
		local r1, r2, r3 = original(...)
		fn(...)
		return r1, r2, r3
	end
end
function issecretvalue() return false end
function GetServerTime() return 1 end
function GetBuildInfo() return "1.60.1", "70938" end

local function FontString(text)
	local fs = {text = text, shown = true}
	function fs:GetText() return self.text end
	function fs:SetText(t) self.text = t end
	function fs:IsShown() return self.shown end
	function fs:GetHeight() return 12 end
	function fs:GetFont() return self.font[1], self.font[2], self.font[3] end
	function fs:SetFont(file, size, flags) self.font = {file, size, flags}; self.fontSets = (self.fontSets or 0) + 1 end
	fs.font = {"Fonts\\FRIZQT__.TTF", 13, ""}
	return fs
end
local function Button(text)
	local b = FontString(text)
	b.scripts = {}
	function b:GetID() return self.id end
	function b:GetTextHeight() return 12 end
	function b:SetHeight(h) self.height = h end
	function b:SetTextAndResize(t) self:SetText(t) end
	function b:SetFormattedText(f, ...) self:SetText(string.format(f, ...)) end
	function b:HookScript(name, fn) self.scripts[name] = fn end
	return b
end

-- Quest Completist
qcQuestDatabase = {
	[784] = {"Vanquish the Betrayers", 7, 14, 1, 2, 0, 8191},
	[825] = {"From The Wreckage....", 8, 14, 1, 2, 0, 8191},
	[831] = {"The Admiral's Orders", 7, 14, 1, 2, 0, 8191},
	[900] = {"Same Name", 10, 14, 1, 2, 0, 8191},
	[901] = {"Same Name", 20, 14, 1, 2, 0, 8191},
	[902] = {"No Level", 0, 14, 1, 2, 0, 8191},
}
qcMapTooltip = {lines = 0, shows = 0}
function qcMapTooltip:NumLines() return self.lines end
function qcMapTooltip:GetOwner() return self.owner end
function qcMapTooltip:Show() self.shows = self.shows + 1 end
local function tipLine(left, right)
	local n = qcMapTooltip.lines + 1
	qcMapTooltip.lines = n
	_G["qcMapTooltipTextLeft" .. n] = FontString(left)
	_G["qcMapTooltipTextRight" .. n] = FontString(right)
	_G["qcMapTooltipTextRight" .. n].shown = right ~= nil
end

-- The game's windows
C_QuestLog = {
	GetQuestDifficultyLevel = function(id) return id == 999 and 33 or (id == 784 and 9 or 0) end,
	GetTitleForQuestID = function() return nil end,
}
GossipSharedAvailableQuestButtonMixin = {Setup = function(self, info)
	self:UpdateTitleForQuest(info.questID, info.title, info.isIgnored, info.isTrivial)
end}
GossipSharedActiveQuestButtonMixin = {Setup = GossipSharedAvailableQuestButtonMixin.Setup}
GossipOptionButtonMixin = {Setup = function(self, info) self:SetText(info.name) end}
local function GossipButton(mixin)
	local b = Button()
	function b:UpdateTitleForQuest(_, title, _, trivial)
		self:SetFormattedText(trivial and "%s (low level)" or "%s", title)
	end
	-- As the game's own button does: its Setup calls the shared mixin's by table lookup.
	function b:Setup(info) mixin.Setup(self, info) end
	return b
end

local greetingButtons = {}
QuestFrameGreetingPanel = Button()
QuestFrameGreetingPanel.titleButtonPool = {EnumerateActive = function()
	local i = 0
	return function() i = i + 1; return greetingButtons[i] end
end}
local greeting = {
	active = {{id = 831, title = "The Admiral's Orders"}},
	available = {{id = 784, title = "Vanquish the Betrayers"}, {id = 902, title = "No Level"}},
}
function GetActiveQuestID(i) return greeting.active[i].id end
function GetActiveTitle(i) return greeting.active[i].title, false end
function GetAvailableQuestInfo(i) return false, 0, false, false, greeting.available[i].id end
function GetAvailableTitle(i) return greeting.available[i].title end
function QuestFrameGreetingPanel_OnShow()
	greetingButtons = greetingButtons.kept or greetingButtons
	local n = 0
	for kind, isActive in pairs({active = 1, available = 0}) do
		for i, q in ipairs(greeting[kind]) do
			n = n + 1
			local b = greetingButtons[n] or Button()
			greetingButtons[n] = b
			b.id, b.isActive = i, isActive
			b:SetText(q.title)
		end
	end
end

local currentQuest, currentTitle = 784, "Vanquish the Betrayers"
function GetQuestID() return currentQuest end
function GetTitleText() return currentTitle end
QuestInfoFrame = {}
QuestInfoTitleHeader = FontString()
QuestProgressTitleText = FontString()
QuestInfoTitleHeader.font = {"Fonts\\MORPHEUS.TTF", 18, ""}
QuestProgressTitleText.font = {"Fonts\\MORPHEUS.TTF", 18, ""}
QuestInfoDescriptionText = FontString()
QuestProgressText = FontString()
QuestFrameProgressPanel = Button()
function QuestInfo_Display() QuestInfoTitleHeader:SetText("|A:icon:16:16|a " .. currentTitle) end

GreetingOnShowOriginal, QuestInfoDisplayOriginal, MapTooltipShowOriginal = QuestFrameGreetingPanel_OnShow, QuestInfo_Display, qcMapTooltip.Show

local onEvent
function CreateFrame()
	return {RegisterEvent = function() end, SetScript = function(_, _, fn) onEvent = fn end}
end

-- The game's settings functions, as the option uses them.
local registered = {}
Settings = {
	VarType = {Boolean = "boolean"},
	RegisterVerticalLayoutCategory = function(name) registered.category = name; return {name = name} end,
	RegisterAddOnSetting = function(_, variable, key, tbl, _, name, default)
		if tbl[key] == nil then tbl[key] = default end
		registered.setting = {variable = variable, key = key, tbl = tbl, name = name}
		return registered.setting
	end,
	CreateCheckbox = function(_, setting)
		registered.checkbox = registered.checkbox or setting
		registered.boxes = (registered.boxes or 0) + 1
		registered[setting.key] = setting
	end,
	RegisterAddOnCategory = function(category) registered.added = category.name end,
}

-- A new install keeps DialogKey's numbers; a save from 1.0.0 (which always hid them) keeps hiding.
local chunk = assert(loadfile(arg[1]))
QuestCompletistPlusDB = nil
chunk("QuestCompletistPlus", {})
onEvent(nil, "PLAYER_LOGIN")
check("new install: numbers kept", QuestCompletistPlusDB.hideDialogKeyNumbers, false)
check("options category", registered.added, "Quest Completist+")
check("option writes to the saved table", registered.checkbox.tbl == QuestCompletistPlusDB and registered.checkbox.key, "hideDialogKeyNumbers")

-- Each start hooks again, so the game's own functions are put back as a fresh game has them.
local function freshGame()
	GossipSharedAvailableQuestButtonMixin = {Setup = function(self, info)
		self:UpdateTitleForQuest(info.questID, info.title, info.isIgnored, info.isTrivial)
	end}
	GossipSharedActiveQuestButtonMixin = {Setup = GossipSharedAvailableQuestButtonMixin.Setup}
	GossipOptionButtonMixin = {Setup = function(self, info) self:SetText(info.name) end}
	QuestFrameGreetingPanel.scripts = {}
	QuestFrameProgressPanel.scripts = {}
	rawset(_G, "QuestFrameGreetingPanel_OnShow", GreetingOnShowOriginal)
	rawset(_G, "QuestInfo_Display", QuestInfoDisplayOriginal)
	qcMapTooltip.Show = MapTooltipShowOriginal
end
freshGame()
QuestCompletistPlusDB = {load = {version = "1.0.0"}}
chunk("QuestCompletistPlus", {})
onEvent(nil, "PLAYER_LOGIN")
check("save from 1.0.0: numbers hidden", QuestCompletistPlusDB.hideDialogKeyNumbers, true)
for name, made in pairs(QuestCompletistPlusDB.load.hooks) do check("hook " .. name, made, true) end
check("level source", QuestCompletistPlusDB.load.questCompletistLevels, "ok")

print("-- 1. map icon list")
qcMapTooltip.owner = {PinData = {1, 3139, "Gar'Thok", 51.95, 43.5, {784, 825, 831, 900, 901, 902}}}
tipLine("Gar'Thok", "|cff8080803139|r")
tipLine("    |cffffffffVanquish the Betrayers|r", "|cff808080784|r")
tipLine("    |A:questlog-questtypeicon-pvp:14:14|a |cff9d9d9dFrom The Wreckage....|r |cff808080(Requires level 9)|r", "|cff808080825|r")
tipLine("    |cffffffffThe Admiral's Orders|r", nil)
tipLine("    |cffffffffSame Name|r", nil)
tipLine("    |cffffffffSame Name|r", "|cff808080901|r")
tipLine("    |cffffffffNo Level|r", "|cff808080902|r")
tipLine("    |cff7fbf7f3 done|r", "|cff808080Shift|r")
tipLine("|cff808080Alt-click to list|r", nil)
qcMapTooltip:Show()
check("giver line untouched", qcMapTooltipTextLeft1.text, "Gar'Thok")
check("by ID", qcMapTooltipTextLeft2.text, "    |cffffffff[7] Vanquish the Betrayers|r")
check("icon and needs kept", qcMapTooltipTextLeft3.text, "    |A:questlog-questtypeicon-pvp:14:14|a |cff9d9d9d[8] From The Wreckage....|r |cff808080(Requires level 9)|r")
check("by name, IDs off", qcMapTooltipTextLeft4.text, "    |cffffffff[7] The Admiral's Orders|r")
check("same name, two levels, no ID: left alone", qcMapTooltipTextLeft5.text, "    |cffffffffSame Name|r")
check("same name with ID", qcMapTooltipTextLeft6.text, "    |cffffffff[20] Same Name|r")
check("level 0: left alone", qcMapTooltipTextLeft7.text, "    |cffffffffNo Level|r")
check("done fold untouched", qcMapTooltipTextLeft8.text, "    |cff7fbf7f3 done|r")
check("shown twice (resize), no loop", qcMapTooltip.shows, 2)
qcMapTooltip:Show()
check("second show writes nothing more", qcMapTooltipTextLeft2.text, "    |cffffffff[7] Vanquish the Betrayers|r")
qcMapTooltip.owner = {Icon = {}}
qcMapTooltipTextLeft2.text = "    |cff808080Available|r"
qcMapTooltipTextRight2.text = "|cff808080784|r"
qcMapTooltip:Show()
check("continent icon: untouched", qcMapTooltipTextLeft2.text, "    |cff808080Available|r")

print("-- 2a. gossip, no DialogKey")
local b = GossipButton(GossipSharedAvailableQuestButtonMixin)
b:Setup({questID = 784, title = "Vanquish the Betrayers", questLevel = 9})
check("available quest", b.text, "[7] Vanquish the Betrayers")
b = GossipButton(GossipSharedActiveQuestButtonMixin)
b:Setup({questID = 999, title = "Unknown To The Addon", questLevel = 33, isTrivial = true})
check("game's level when the addon lacks the quest, trivial format kept", b.text, "[33] Unknown To The Addon (low level)")
b = GossipButton(GossipSharedAvailableQuestButtonMixin)
b:Setup({questID = 902, title = "No Level", questLevel = 0})
check("no level", b.text, "No Level")
check("mismatch noted (784: addon 7, game 9)", QuestCompletistPlusDB.mismatch[784] and table.concat(QuestCompletistPlusDB.mismatch[784], "/"), "7/9")

print("-- 2a. gossip with DialogKey (its guard as in main.lua 293-305)")
local function DialogKeyAcquire(button, info)
	button:SetTextAndResize(info.DialogKeyNumy_Text)
	if not button.DialogKeyNumy_Text then
		local function onSetText(f, text)
			local saved = f.DialogKeyNumy_Text
			if not saved or saved == "" or saved == text then return end
			f:SetTextAndResize(saved)
		end
		hooksecurefunc(button, "SetText", onSetText)
		hooksecurefunc(button, "SetFormattedText", function(f, format, ...) onSetText(f, format:format(...)) end)
	end
	button.DialogKeyNumy_Text = info.DialogKeyNumy_Text
end
-- Order A: row measured first (our hook rewrites the kept text), then the button is acquired and set up.
local info = {questID = 825, title = "From The Wreckage....", questLevel = 8, isTrivial = true,
	DialogKeyNumy_Text = "1. From The Wreckage.... (low level)"}
local measure = GossipButton(GossipSharedAvailableQuestButtonMixin)
measure:Setup(info)
check("measuring button", measure.text, "[8] From The Wreckage.... (low level)")
local real = GossipButton(GossipSharedAvailableQuestButtonMixin)
DialogKeyAcquire(real, info)
real:Setup(info)
check("order A: real button", real.text, "[8] From The Wreckage.... (low level)")
check("order A: DialogKey's kept text", real.DialogKeyNumy_Text, "[8] From The Wreckage.... (low level)")
-- Order B: acquired with the numbered text before anything of ours ran.
info = {questID = 831, title = "The Admiral's Orders", questLevel = 7, DialogKeyNumy_Text = "2. The Admiral's Orders"}
real = GossipButton(GossipSharedActiveQuestButtonMixin)
DialogKeyAcquire(real, info)
check("order B: before set-up DialogKey's number shows", real.text, "2. The Admiral's Orders")
real:Setup(info)
check("order B: after set-up", real.text, "[7] The Admiral's Orders")
real:SetText("something else")
check("DialogKey now holds our text", real.text, "[7] The Admiral's Orders")
-- A talk option: number off, nothing added.
info = {name = "I want to browse your goods.", DialogKeyNumy_Text = "3. I want to browse your goods."}
real = Button()
function real:Setup(i) GossipOptionButtonMixin.Setup(self, i) end
DialogKeyAcquire(real, info)
real:Setup(info)
check("talk option", real.text, "I want to browse your goods.")

print("-- 2b. greeting")
QuestFrameGreetingPanel_OnShow()
local texts = {}
for i, button in ipairs(greetingButtons) do texts[i] = button.text end
table.sort(texts)
check("greeting texts", table.concat(texts, " | "), "No Level | [7] The Admiral's Orders | [7] Vanquish the Betrayers")
-- DialogKey a frame later (main.lua 775-785)
for i, button in ipairs(greetingButtons) do button:SetText(i .. ". " .. button:GetText()) end
texts = {}
for i, button in ipairs(greetingButtons) do texts[i] = button.text end
table.sort(texts)
check("after DialogKey's numbering", table.concat(texts, " | "), "No Level | [7] The Admiral's Orders | [7] Vanquish the Betrayers")
QuestFrameGreetingPanel_OnShow()
texts = {}
for i, button in ipairs(greetingButtons) do texts[i] = button.text end
table.sort(texts)
check("rebuilt (quest log update)", table.concat(texts, " | "), "No Level | [7] The Admiral's Orders | [7] Vanquish the Betrayers")

print("-- DialogKey's numbers kept (the option off, as a new install has it)")
QuestCompletistPlusDB.hideDialogKeyNumbers = false
info = {questID = 825, title = "From The Wreckage....", questLevel = 8, isTrivial = true,
	DialogKeyNumy_Text = "1. From The Wreckage.... (low level)"}
measure = GossipButton(GossipSharedAvailableQuestButtonMixin)
measure:Setup(info)
real = GossipButton(GossipSharedAvailableQuestButtonMixin)
DialogKeyAcquire(real, info)
real:Setup(info)
check("gossip quest", real.text, "1. [8] From The Wreckage.... (low level)")
info = {name = "I want to browse your goods.", DialogKeyNumy_Text = "3. I want to browse your goods."}
real = Button()
function real:Setup(i) GossipOptionButtonMixin.Setup(self, i) end
DialogKeyAcquire(real, info)
real:Setup(info)
check("talk option", real.text, "3. I want to browse your goods.")
QuestFrameGreetingPanel_OnShow()
for i, button in ipairs(greetingButtons) do button:SetText(i .. ". " .. button:GetText()) end
texts = {}
for i, button in ipairs(greetingButtons) do texts[i] = (button.text:gsub("^%d%. ", "N. ")) end
table.sort(texts)
check("greeting", table.concat(texts, " | "), "N. No Level | N. [7] The Admiral's Orders | N. [7] Vanquish the Betrayers")
QuestCompletistPlusDB.hideDialogKeyNumbers = true

print("-- 3. quest window")
QuestInfo_Display()
check("accept page", QuestInfoTitleHeader.text, "|A:icon:16:16|a [7] Vanquish the Betrayers")
QuestInfoFrame.questLog = true
QuestInfo_Display()
check("quest log view left alone", QuestInfoTitleHeader.text, "|A:icon:16:16|a Vanquish the Betrayers")
QuestInfoFrame.questLog = nil
QuestProgressTitleText:SetText(currentTitle)
QuestFrameProgressPanel.scripts.OnShow()
check("progress page", QuestProgressTitleText.text, "[7] Vanquish the Betrayers")
currentQuest, currentTitle = 999, "Unknown To The Addon"
QuestInfo_Display()
check("game's level fallback", QuestInfoTitleHeader.text, "|A:icon:16:16|a [33] Unknown To The Addon")

print("-- 3b. quest title font")
local function font(fs) return fs.font[1] .. " " .. fs.font[2] end
check("two options", registered.boxes >= 2 and registered.standardTitleFont.name, "Quest title in the standard font")
check("on by default", QuestCompletistPlusDB.standardTitleFont, true)
check("accept page: the body text's font, two points smaller", font(QuestInfoTitleHeader), "Fonts\\FRIZQT__.TTF 16")
check("progress page", font(QuestProgressTitleText), "Fonts\\FRIZQT__.TTF 16")
local sets = QuestInfoTitleHeader.fontSets
QuestInfo_Display()
check("set once, not on every open", QuestInfoTitleHeader.fontSets, sets)
QuestInfoFrame.questLog = true
QuestInfo_Display()
check("quest log view: the game's font back", font(QuestInfoTitleHeader), "Fonts\\MORPHEUS.TTF 18")
QuestInfoFrame.questLog = nil
QuestInfo_Display()
check("NPC window again", font(QuestInfoTitleHeader), "Fonts\\FRIZQT__.TTF 16")
QuestCompletistPlusDB.standardTitleFont = false
QuestInfo_Display()
QuestFrameProgressPanel.scripts.OnShow()
check("option off: the game's font back", font(QuestInfoTitleHeader) .. " | " .. font(QuestProgressTitleText), "Fonts\\MORPHEUS.TTF 18 | Fonts\\MORPHEUS.TTF 18")
check("option off: level still written", QuestInfoTitleHeader.text, "|A:icon:16:16|a [33] Unknown To The Addon")
QuestCompletistPlusDB.standardTitleFont = true

print("-- saved file")
for name, place in pairs(QuestCompletistPlusDB.places) do
	local skipped = {}
	for why, count in pairs(place.skipped) do skipped[#skipped + 1] = why .. "=" .. count end
	table.sort(skipped)
	print(string.format("   %s: wrote %d, skipped {%s}", name, place.wrote, table.concat(skipped, ", ")))
end
print(string.format("   DialogKey numbers removed: gossip %d, greeting %d", QuestCompletistPlusDB.dialogKey.gossip, QuestCompletistPlusDB.dialogKey.greeting))
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
