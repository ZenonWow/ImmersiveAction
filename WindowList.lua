local _G, ADDON_NAME, _ADDON = _G, ...
-- This file lists window names that need visible mousecursor so that the user can interact with them.
-- Exports:  _ADDON.WindowList:  an array (list) of frame names.


------------------------------
-- List of interactive frames/windows that aren't registered in UIPanelWindows, UISpecialFrames, UIMenus (@see FrameXML/UIParent.lua):
-- This list is based on Mouse-Look-Lock addon's collection with above mentioned entries filtered.
------------------------------

local WindowListSerialized =
[===[
BattlefieldFrame         VoiceMacroMenu           CoinPickupFrame          CraftFrame               OptionsFrame
PaperDollFrame           PetPaperDollFrame        PetRenamePopup           PetStable                RaidFrame
ReputationFrame          ScriptErrors             SkillFrame               SoundOptionsFrame        StackSplitFrame
StatsFrame               SuggestFrame             TalentFrame              TalentTrainerFrame       TutorialFrame
UIOptionsFrame           UnitPopup                CosmosMasterFrame        CosmosDropDown           ChooseItemsFrame
ImprovedErrorFrame       TicTacToeFrame           OthelloFrame             MinesweeperFrame         GamesListFrame
ConnectFrame             ChessFrame               QuestShareFrame          TotemStomperFrame        WantAds
StaticPopup1             StaticPopup2             StaticPopup3             StaticPopup4             DropDownList3            
CosmosDropDownBis        InventoryManagerFrame    InspectPaperDollFrame    
ContainerFrame1          ContainerFrame2          ContainerFrame3          ContainerFrame4          ContainerFrame5          
ContainerFrame6          ContainerFrame7          ContainerFrame8          ContainerFrame9          ContainerFrame10         
ContainerFrame11         ContainerFrame12         ContainerFrame13         ContainerFrame14         ContainerFrame15         
NxSocial                 ARKINV_Frame1            WardrobeFrame            ACP_AddonList            AutoPotion_Template_Dialog
AccountantFrame          ImmersionFrame           BagnonFrameinventory     GwCharacterWindow        GwCharacterWindowsMoverFrame
FlightMapFrame           MovieFrame.CloseDialog   CinematicFrameCloseDialog
AdiBagsContainer1        AdiBackpack              AdiBank                  ElephantFrame            
]===]
-- To get the frame  MovieFrame.CloseDialog  use the function  getSubField(_G, name)


--- getSubField(root, name)
-- Get a field of a field (of a field) in root, recursively traveling to any depth in the tree.
-- E.g. getSubField(_G, 'MovieFrame.CloseDialog')  will return _G.MovieFrame.CloseDialog == _G['MovieFrame']['CloseDialog']
-- @param root (table) - starting point
-- @param name (string) - field names to follow, separated by one dot ("."), no whitespace, no square brackets
-- Just as it is written in Lua code.
-- Does not support square brackets (eg. MovieFrame["CloseDialog"]), that would require intricate logic, unnecessary in this use-case.
function _ADDON.getSubField(root, name)
	for i,fieldName in ipairs({ string.split(".", name) }) do
		if not root then  return nil  end
		root = root[fieldName]
	end
	return root
end




------------------------------
-- List of UIPanelWindows that were not listed (therefore monitored) in earlier versions:
------------------------------
--[[
local framesNotMonitoredBefore =
[===[
ItemRefTooltip           ColorPickerFrame         CalendarContextMenu      ScrollOfResurrectionFrame  ScrollOfResurrectionSelectionFrame
AudioOptionsFrame        PVPBannerFrame           PetStableFrame           PVPBannerFrame           QuestLogDetailFrame
DressUpFrame             PetitionFrame            ItemTextFrame            RaidParentFrame          RaidBrowserFrame
CinematicFrame           ChatConfigFrame          WorldStateScoreFrame     QuestChoiceFrame         ArchaeologyFrame
BlackMarketFrame         CalendarFrame            GMSurveyFrame            GuildBankFrame           TransmogrifyFrame
ItemSocketingFrame       ItemUpgradeFrame         ReforgingFrame           TokenFrame               VoidStorageFrame
]===]
--]]


------------------------------
-- List of builtin windows registered in UIPanelWindows, UISpecialFrames, UIMenus
-- For reference, extracted from FrameXML/UIParent.lua and AddOns/Blizzard_*/*.lua
------------------------------
--[[
local grepFromFrameXML =
--- UIChildWindows[]  in  FrameXML/UIParent.lua:
-- "OpenMailFrame       GuildControlUI  GuildMemberDetailFrame  TokenFramePopup  GuildBankPopupFrame  GearManagerDialog  "..
--- UISpecialFrames[]  in  FrameXML/UIParent.lua:
"ItemRefTooltip      ColorPickerFrame    ScrollOfResurrectionFrame  ScrollOfResurrectionSelectionFrame  "..
--- UIMenus[]  in  FrameXML/UIParent.lua:
"ChatMenu            EmoteMenu           LanguageMenu        DropDownList1       DropDownList2       "..
--- UIMenus[]  in  Blizzard_Calendar/Blizzard_Calendar.lua:
"CalendarContextMenu "..
--- UIPanelWindows{}  in  FrameXML/UIParent.lua:
-- Center Menu Frames
"GameMenuFrame       VideoOptionsFrame   AudioOptionsFrame   InterfaceOptionsFrame HelpFrame         "..
-- Frames using the new Templates
"CharacterFrame      SpellBookFrame      TaxiFrame           PVPUIFrame          PVPBannerFrame      "..
"PetStableFrame      PVEFrame            EncounterJournal    PetJournalParent    TradeFrame          "..
"LootFrame           MerchantFrame       TabardFrame         PVPBannerFrame      MailFrame           "..
"BankFrame           QuestLogFrame       QuestLogDetailFrame QuestFrame          GuildRegistrarFrame "..
"GossipFrame         DressUpFrame        PetitionFrame       ItemTextFrame       FriendsFrame        "..
"RaidParentFrame     RaidBrowserFrame    "..
-- Frames NOT using the new Templates
"WorldMapFrame       CinematicFrame      ChatConfigFrame     WorldStateScoreFrame  QuestChoiceFrame  "..
--- UIPanelWindows{}  in  AddOns/Blizzard_*/*.lua:
"AchievementFrame    ArchaeologyFrame    AuctionFrame        KeyBindingFrame     BlackMarketFrame    "..
"CalendarFrame       GMSurveyFrame       GuildBankFrame      GuildFrame          InspectFrame        "..
"TransmogrifyFrame   ItemSocketingFrame  ItemUpgradeFrame    LookingForGuildFrameMacroFrame          "..
"ReforgingFrame      PlayerTalentFrame   TokenFrame          TradeSkillFrame     ClassTrainerFrame   "..
"VoidStorageFrame    "

--]]



------------------------------
-- Parse window list string --
------------------------------

local WindowList = {}

-- for name in WindowListSerialized:gmatch("[%w%.]+") do
for name in WindowListSerialized:gmatch("[^,%s]+") do
	WindowList[#WindowList+1] = name
end

-- garbagecollect
WindowListSerialized = nil


------------------------------
-- Export  WindowList  to addon's private namespace.
-- WindowList:  an array (list) of frame names.
------------------------------
_ADDON.WindowList = WindowList

