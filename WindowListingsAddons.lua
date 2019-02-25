--[[
This file was used in the compilation of the FrameList for MonitoredFrames.lua.
It is not loaded in the wow client.
--]]




------------------------------
-- List extracted from FrameXML and Blizzard_* addons.
------------------------------

local grepFromFrameXML =
--- UIChildWindows[]  in  FrameXML/UIParent.lua:
-- "OpenMailFrame       ,GuildControlUI  ,GuildMemberDetailFrame  ,TokenFramePopup     ,GuildBankPopupFrame ,GearManagerDialog   ,"..
--- UISpecialFrames[]  in  FrameXML/UIParent.lua:
"ItemRefTooltip      ,ColorPickerFrame    ,ScrollOfResurrectionFrame  ,ScrollOfResurrectionSelectionFrame  ,"..
--- UIMenus[]  in  FrameXML/UIParent.lua:
-- "ChatMenu            ,EmoteMenu           ,LanguageMenu        ,DropDownList1       ,DropDownList2       ,"..
--- UIMenus[]  in  Blizzard_Calendar/Blizzard_Calendar.lua:
-- "CalendarContextMenu ,"..
--- UIPanelWindows{}  in  FrameXML/UIParent.lua:
-- Center Menu Frames
"GameMenuFrame       ,VideoOptionsFrame   ,AudioOptionsFrame   ,InterfaceOptionsFrame ,HelpFrame         ,"..
-- Frames using the new Templates
"CharacterFrame      ,SpellBookFrame      ,TaxiFrame           ,PVPUIFrame          ,PVPBannerFrame      ,"..
"PetStableFrame      ,PVEFrame            ,EncounterJournal    ,PetJournalParent    ,TradeFrame          ,"..
"LootFrame           ,MerchantFrame       ,TabardFrame         ,PVPBannerFrame      ,MailFrame           ,"..
"BankFrame           ,QuestLogFrame       ,QuestLogDetailFrame ,QuestFrame          ,GuildRegistrarFrame ,"..
"GossipFrame         ,DressUpFrame        ,PetitionFrame       ,ItemTextFrame       ,FriendsFrame        ,"..
"RaidParentFrame     ,RaidBrowserFrame    ,"..
-- Frames NOT using the new Templates
"WorldMapFrame       ,CinematicFrame      ,ChatConfigFrame   ,WorldStateScoreFrame  ,QuestChoiceFrame    ,"..
--- UIPanelWindows{}  in  AddOns/Blizzard_*/*.lua:
"AchievementFrame    ,ArchaeologyFrame    ,AuctionFrame        ,KeyBindingFrame     ,BlackMarketFrame    ,"..
"CalendarFrame       ,GMSurveyFrame       ,GuildBankFrame      ,GuildFrame          ,InspectFrame        ,"..
"TransmogrifyFrame   ,ItemSocketingFrame  ,ItemUpgradeFrame    ,LookingForGuildFrame,MacroFrame          ,"..
"ReforgingFrame      ,PlayerTalentFrame   ,TokenFrame          ,TradeSkillFrame     ,ClassTrainerFrame   ,"..
"VoidStorageFrame    ,"






------------------------------
-- List from CombatMode with additions.
------------------------------

local FramesToHook = {
	"AuctionFrame",       "BankFrame",          "BattlefieldFrame",   "CharacterFrame",
	"ChatMenu",           "EmoteMenu",          "LanguageMenu",       "VoiceMacroMenu",
	"ClassTrainerFrame",  "CoinPickupFrame",    "CraftFrame",         "FriendsFrame",
	"GameMenuFrame",      "GossipFrame",        "GuildRegistrarFrame","HelpFrame",
	"InspectFrame",       "KeyBindingFrame",    "LootFrame",          "MacroFrame",
	"MailFrame",          "MerchantFrame",      "OptionsFrame",       "PaperDollFrame",
	"PetPaperDollFrame",  "PetRenamePopup",     "PetStable",          "QuestFrame",
	"QuestLogFrame",      "RaidFrame",          "ReputationFrame",    "ScriptErrors",
	"SkillFrame",         "SoundOptionsFrame",  "SpellBookFrame",     "StackSplitFrame",
	"StatsFrame",         "SuggestFrame",       "TabardFrame",        "TalentFrame",
	"TalentTrainerFrame", "TaxiFrame",          "TradeFrame",         "TradeSkillFrame",
	"TutorialFrame",      "UIOptionsFrame",     "UnitPopup",          
	"CosmosMasterFrame",  "CosmosDropDown",     "ChooseItemsFrame",   "ImprovedErrorFrame",
	"TicTacToeFrame",     "OthelloFrame",       "MinesweeperFrame",   "GamesListFrame",
	"ConnectFrame",       "ChessFrame",         "QuestShareFrame",    "TotemStomperFrame",
	"StaticPopup1",       "StaticPopup2",       "StaticPopup3",       "StaticPopup4",
	"DropDownList1",      "DropDownList2",      "DropDownList3",      "WantAds",
	"CosmosDropDownBis",  "InventoryManagerFrame", "InspectPaperDollFrame",
	"ContainerFrame1",    "ContainerFrame2",    "ContainerFrame3",    "ContainerFrame4",
	"ContainerFrame5",    "ContainerFrame6",    "ContainerFrame7",    "ContainerFrame8",
	"ContainerFrame9",    "ContainerFrame10",   "ContainerFrame11",   "ContainerFrame12",
	"ContainerFrame13",   "ContainerFrame14",   "ContainerFrame15",   "ContainerFrame16",
	"ContainerFrame17",   "AutoPotion_Template_Dialog","NxSocial",    "ARKINV_Frame1",
	"AchievementFrame",   "LookingForGuildFrame", "PVPUIFrame",       "GuildFrame",
	"WorldMapFrame",      "VideoOptionsFrame",  "InterfaceOptionsFrame", "WardrobeFrame",
	"ACP_AddonList",      "PlayerTalentFrame",  "PVEFrame",           "EncounterJournal",
	"PetJournalParent",   "AccountantFrame",
	
	"ImmersionFrame",			"BagnonFrameinventory",		"ElephantFrame",
	"AdiBagsContainer1","AdiBackpack","AdiBank",
	"GwCharacterWindow",	"GwCharacterWindowsMoverFrame",
	
	"CinematicFrameCloseDialog",		-- source: MouselookHandler, ConsolePort
  "MovieFrame.CloseDialog",				-- local getfield() can resolve this, getglobal() can't
	
	-- "NxMap1",			-- Carbonite's world map breaks mouselook
	-- "StoreFrame",	-- causes taint?
} -- end FramesToHook






------------------------------
-- List from CombatMode 1.5.3 addon, based on Mouse-Look-Lock. Fixed StaticPopXXXup1, LoXXXotFrame.
------------------------------

local FramesToCheck = {
	"AuctionFrame",       "BankFrame",          "BattlefieldFrame",   "CharacterFrame",
	"ChatMenu",           "EmoteMenu",          "LanguageMenu",       "VoiceMacroMenu",
	"ClassTrainerFrame",  "CoinPickupFrame",    "CraftFrame",         "FriendsFrame",
	"GameMenuFrame",      "GossipFrame",        "GuildRegistrarFrame","HelpFrame",
	"InspectFrame",       "KeyBindingFrame",    "LootFrame",          "MacroFrame",
	"MailFrame",          "MerchantFrame",      "OptionsFrame",       "PaperDollFrame",
	"PetPaperDollFrame",  "PetRenamePopup",     "PetStable",          "QuestFrame",
	"QuestLogFrame",      "RaidFrame",          "ReputationFrame",    "ScriptErrors",
	"SkillFrame",         "SoundOptionsFrame",  "SpellBookFrame",     "StackSplitFrame",
	"StatsFrame",         "SuggestFrame",       "TabardFrame",        "TalentFrame",
	"TalentTrainerFrame", "TaxiFrame",          "TradeFrame",         "TradeSkillFrame",
	"TutorialFrame",      "UIOptionsFrame",     "UnitPopup",          "WorldMapFrame",
	"CosmosMasterFrame",  "CosmosDropDown",     "ChooseItemsFrame",   "ImprovedErrorFrame",
	"TicTacToeFrame",     "OthelloFrame",       "MinesweeperFrame",   "GamesListFrame",
	"ConnectFrame",       "ChessFrame",         "QuestShareFrame",    "TotemStomperFrame",
	"StaticPopup1",       "StaticPopup2",       "StaticPopup3",       "StaticPopup4",
	"DropDownList1",      "DropDownList2",      "DropDownList3",      "WantAds",
	"CosmosDropDownBis",  "InventoryManagerFrame", "InspectPaperDollFrame",
	"ContainerFrame1",    "ContainerFrame2", "ContainerFrame3", "ContainerFrame4",
	"ContainerFrame5",    "ContainerFrame6",    "ContainerFrame7",    "ContainerFrame8",
	"ContainerFrame9",    "ContainerFrame10",   "ContainerFrame11",   "ContainerFrame12",
	"ContainerFrame13",   "ContainerFrame14",   "ContainerFrame15",   "ContainerFrame16",
	"ContainerFrame17",   "AutoPotion_Template_Dialog","NxSocial",    "ARKINV_Frame1",
	"AchievementFrame",   "LookingForGuildFrame", "PVPUIFrame",       "GuildFrame",
	"WorldMapFrame",      "VideoOptionsFrame",  "InterfaceOptionsFrame", "WardrobeFrame",
    "ACP_AddonList",      "PlayerTalentFrame",  "PVEFrame",           "EncounterJournal",
	"PetJournalParent",   "AccountantFrame", "ImmersionFrame", "BagnonFrameinventory",
	"GwCharacterWindow", "GwCharacterWindowsMoverFrame", --[["StaticPopup1",]] "FlightMapFrame"
}






------------------------------
-- List from ConsolePort addon, Config\Lookup.lua.
------------------------------

local ConsolePort = {
	'AddonList',
	'BagHelpBox',
	'BankFrame',
	'BasicScriptErrors',
	'CharacterFrame',
	'ChatConfigFrame',
	'ChatMenu',
	'CinematicFrameCloseDialog',
	'ContainerFrame1',
	'ContainerFrame2',
	'ContainerFrame3',
	'ContainerFrame4',
	'ContainerFrame5',
	'ContainerFrame6',
	'ContainerFrame7',
	'ContainerFrame8',
	'ContainerFrame9',
	'ContainerFrame10',
	'ContainerFrame11',
	'ContainerFrame12',
	'ContainerFrame13',
	'DressUpFrame',
	'DropDownList1',
	'DropDownList2',
	'FriendsFrame',	
	'GameMenuFrame',
	'GossipFrame',
	'GuildInviteFrame',
	'InterfaceOptionsFrame',
	'ItemRefTooltip',
	'ItemTextFrame',
	'LFDRoleCheckPopup',
	'LFGDungeonReadyDialog',
	'LFGInvitePopup',
	'LootFrame',
	'MailFrame',
	'MerchantFrame',
	'OpenMailFrame',
	'PetBattleFrame',
	'PetitionFrame',
	'PVEFrame',
	'PVPReadyDialog',
	'QuestFrame','QuestLogPopupDetailFrame',
	'RecruitAFriendFrame',
	'ReadyCheckFrame',
	'SpellBookFrame',
	'SplashFrame',
	'StackSplitFrame',
	'StaticPopup1',
	'StaticPopup2',
	'StaticPopup3',
	'StaticPopup4',
	'TaxiFrame',
	'TimeManagerFrame',
	'TradeFrame',
	'TutorialFrame',
	'VideoOptionsFrame',
	'WorldMapFrame',
	'GroupLootFrame1',
	'GroupLootFrame2',
	'GroupLootFrame3',
	'GroupLootFrame4'
}






------------------------------
-- List from Mouse-Look-Lock 7.0 addon.
------------------------------

--List of frames that should automatically undo mouselook while they are up
local MouseLook_FramesToCheck = {
	"AuctionFrame",       "BankFrame",          "BattlefieldFrame",   "CharacterFrame",
	"ChatMenu",           "EmoteMenu",          "LanguageMenu",       "VoiceMacroMenu",
	"ClassTrainerFrame",  "CoinPickupFrame",    "CraftFrame",         "FriendsFrame",
	"GameMenuFrame",      "GossipFrame",        "GuildRegistrarFrame","HelpFrame",
	"InspectFrame",       "KeyBindingFrame",    "LoXXXotFrame",       "MacroFrame",
	"MailFrame",          "MerchantFrame",      "OptionsFrame",       "PaperDollFrame",
	"PetPaperDollFrame",  "PetRenamePopup",     "PetStable",          "QuestFrame",
	"QuestLogFrame",      "RaidFrame",          "ReputationFrame",    "ScriptErrors",
	"SkillFrame",         "SoundOptionsFrame",  "SpellBookFrame",     "StackSplitFrame",
	"StatsFrame",         "SuggestFrame",       "TabardFrame",        "TalentFrame",
	"TalentTrainerFrame", "TaxiFrame",          "TradeFrame",         "TradeSkillFrame",
	"TutorialFrame",      "UIOptionsFrame",     "UnitPopup",          "WorldMapFrame",
	"CosmosMasterFrame",  "CosmosDropDown",     "ChooseItemsFrame",   "ImprovedErrorFrame",
	"TicTacToeFrame",     "OthelloFrame",       "MinesweeperFrame",   "GamesListFrame",
	"ConnectFrame",       "ChessFrame",         "QuestShareFrame",    "TotemStomperFrame",
	"StaticPopXXXup1",       "StaticPopup2",       "StaticPopup3",       "StaticPopup4",
	"DropDownList1",      "DropDownList2",      "DropDownList3",      "WantAds",
	"CosmosDropDownBis",  "InventoryManagerFrame", "InspectPaperDollFrame",
	"ContainerFrame1",    "ContainerFrame2", "ContainerFrame3", "ContainerFrame4",
	"ContainerFrame5",    "ContainerFrame6",    "ContainerFrame7",    "ContainerFrame8",
	"ContainerFrame9",    "ContainerFrame10",   "ContainerFrame11",   "ContainerFrame12",
	"ContainerFrame13",   "ContainerFrame14",   "ContainerFrame15",   "ContainerFrame16",
	"ContainerFrame17",   "AutoPotion_Template_Dialog","NxSocial",    "ARKINV_Frame1",
	"AchievementFrame",   "LookingForGuildFrame", "PVPUIFrame",       "GuildFrame",
	"WorldMapFrame",      "VideoOptionsFrame",  "InterfaceOptionsFrame",
        "ACP_AddonList",      "PlayerTalentFrame",  "PVEFrame",           "EncounterJournal",
	"PetJournalParent",   "AccountantFrame", "AdiBagsContainer1", "ElvUI_ContainerFrame",
	"GarrisonLandingPage", "GarrisonMissionFrame", "GarrisonBuildingFrame",
	--   "NxMap1",  (carbonite's world map breaks mouselook)
	-- "StoreFrame", (causes taint??!??  wtf, blizzard?)
	----[[
}

--List of frames that mouse might be over (Yes, these could badly use some cleanup)
local MouseLook_FramesToCheckForMouse = {
	--]]
	"BonusActionBarFrame",
	"BuffFrame",
	"CastingBarFrame",
	"ChatFrameMenuButton", "ChatFrameEditBox",
	"ChatFrame1Tab", "ChatFrame2Tab", "ChatFrame3Tab", "ChatFrame4Tab", "ChatFrame5Tab", "ChatFrame6Tab", "ChatFrame7Tab",
	"ChatFrame1BottomButton", "ChatFrame2BottomButton", "ChatFrame3BottomButton", "ChatFrame4BottomButton", "ChatFrame5BottomButton", "ChatFrame6BottomButton", "ChatFrame7BottomButton",
	"ChatFrame1DownButton", "ChatFrame2DownButton", "ChatFrame3DownButton", "ChatFrame4DownButton", "ChatFrame5DownButton", "ChatFrame6DownButton", "ChatFrame7DownButton",
	"ChatFrame1UpButton", "ChatFrame2UpButton", "ChatFrame3UpButton", "ChatFrame4UpButton", "ChatFrame5UpButton", "ChatFrame6UpButton", "ChatFrame7UpButton",
	"CoinPickupFrame",
	"ColorPickerFrame",
	"DialogBoxFrame",
	"DurabilityFrame",
	"GameTimeFrame",
	"ItemTextFrame",
	"MainMenuBar",
	"MinimapCluster",
	"PartyFrame",
	"PetActionBarFrame", "PetFrame", "PetitionFrame",
	"PlayerFrame",
	"QuestTimerFrame",
	"TargetFrame",
	"UnitFrame",
	"AutoFollowStatus",
	"SecondBar",
	"ClockFrame",
	"CosmosTooltip",
	"CombatStatsDataFrame",
	"CombatStatsFrame",
	"DPSPLUS_PlayerFrame",
	"ItemBuffBar",
	"ItemBuffButton1", "ItemBuffButton2", "ItemBuffButton3", "ItemBuffButton4", "ItemBuffButton5", "ItemBuffButton6",
	"KillCountFrame", "KillCountFrame2",
	"InventoryManagerTooltip",
	"MonitorStatus",
	"SideBar", "SideBar2",
	"TargetDistanceFrame",
	"TargetStatsTooltip",
	"HealomaticMainFrame",
}






------------------------------
-- Calculate differences in lists:
------------------------------



-- local SEP = "        " -- 8
local columnLen = 25

local function printList(list)
	local s,name,col,pad
	for i = 1,#list,5 do
		s, col = nil, 0
		for j = i,min(i+4,#list) do
			name = list[j]
			pad =  s and string.rep(" ", max(2, col - #s))
			s = s  and  s..pad..name  or  name
			col = col + columnLen
		end
		print(s)
	end
end


local function DiffLists(collectedFrames)

	local grepFrames = {}
	-- for name in grepFromFrameXML:gmatch("[^,%s]+") do
	for name in grepFromFrameXML:gmatch("%w+") do
		-- print(name..'|')
		grepFrames[#grepFrames+1] = name
		grepFrames[name] = #grepFrames
	end
	for i,name in ipairs(collectedFrames) do
		-- collectedFrames[i] = name
		collectedFrames[name] = i
	end

	local notInUIFrames, missing = {}, {}
	for i,name in ipairs(collectedFrames) do
		if not grepFrames[name] then
			notInUIFrames[#notInUIFrames+1] = name
			notInUIFrames[name] = #notInUIFrames
		end
	end
	for i,name in ipairs(grepFrames) do
		if not collectedFrames[name] then
			missing[#missing+1] = name
			missing[name] = #missing
		end
	end

	print("\n\n", "Listed in addon, but not in FrameXML UIPanelWindows/UISpecialFrames/UIMenus:\n")
	printList(notInUIFrames)
	print("\n\n", "Listed in FrameXML, but not the addon:\n")
	printList(missing)

end


print("\n\n\n\n\t", "CombatModeMod:")
DiffLists(FramesToHook)
print("\n\n\n\n\t", "CombatMode:")
DiffLists(FramesToCheck)
print("\n\n\n\n\t", "ConsolePort:")
DiffLists(ConsolePort)
print("\n\n\n\n\t", "MouseLookLock:")
DiffLists(MouseLook_FramesToCheck)




