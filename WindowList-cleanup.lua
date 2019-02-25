ImmersiveAction.FramesReleasingMouseCleanup = {
	'GameMenuFrame','InterfaceOptionsFrame','VideoOptionsFrame',
	'WorldMapFrame',
	'AuctionFrame','BankFrame','CharacterFrame','BattlefieldFrame',

	'ChatMenu','EmoteMenu','LanguageMenu','VoiceMacroMenu',

	'FriendsFrame','RaidFrame',
	'WhoFrame','ChannelFrame',	-- new in client 7.0?

	'ClassTrainerFrame','CoinPickupFrame','CraftFrame',
	'GossipFrame','GuildRegistrarFrame','HelpFrame',
	
	"InspectFrame",       "KeyBindingFrame",    "LoXXXotFrame",       "MacroFrame",
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
	"StaticPopXXXup1",    "StaticPopup2",       "StaticPopup3",       "StaticPopup4",
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
	
	'ImmersionFrame','BagnonFrameinventory',"AdiBagsContainer1","ElephantFrame",
	'GwCharacterWindow','GwCharacterWindowsMoverFrame',
	
	-- 'NxMap1',  (carbonite's world map breaks mouselook)
	-- 'StoreFrame', (causes taint??!??  wtf, blizzard?)
} -- end ImmersiveAction.FramesReleasingMouse





--[[
Conditionals:
--
button:1/.../5/<virtual click> or btn:1/.../5/<virtual click> — Macro activated with the given mouse button.
Similar to [modifier], [button] allows your macro to respond differently based on which mouse button is being used to activate the macro. Button numbers 1-5 correspond to left, right, middle, button 4, and button 5. If your macro is activated by a keybinding, [button:1] will always be true. As an example, here is the macro I use for mounting:

modifier:shift/ctrl/alt or mod:shift/ctrl/alt — Holding the given key.
While modifier keys can only be one of shift, ctrl, or alt, there are a number of system variables that you can use in your modifier conditions as well. For instance, the SELFCAST variable means "whatever your self-cast modifier is set to." The default is alt (holding the alt key while casting a spell will attempt to cast it on yourself) though some addons give you the option to change this. If you create a macro like:
/cast [modifier:SELFCAST, @player] [@mouseover] [ ] Greater Heal

cursor — The mouse cursor is currently holding an item/ability/macro/etc.
combat — Player is in combat.
exists — Conditional target exists.
help — Conditional target exists and can be targeted by helpful spells (e.g.  [Heal]).

flyable — The player can use a flying mount in this zone (though incorrect in Wintergrasp during a battle).
--]]


Showing/hiding a unit frame:

local frame = CreateFrame("Button", "MyParty1", UIParent, "SecureUnitButtonTemplate")
frame:SetAttribute("unit", "party1")
RegisterUnitWatch(frame)
    
frame:SetPoint("CENTER")
frame:SetSize(50, 50)
frame:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = true, tileSize = 8 })
frame:SetBackdropColor(1, 0, 0)
The snippet above will display a clickable unit frame for the "party1" unit (consisting solely of a red square in the center of your screen) only when the unit exists.

Responding to custom states

local frame = CreateFrame("Frame", "MyStatefulFrame", UIParent, "SecureHandlerStateTemplate")
RegisterStateDriver(frame, "petstate", "[@pet,noexists] nopet; [@pet,help] mypet; [@pet,harm] mcpet")
frame:SetAttribute("_onstate-petstate", [[ -- arguments: self, stateid, newstate
    if newstate == "nopet" then
        print("Where are you, kitty?")
    elseif newstate == "mypet" then
        print("Oh hai, kitty!")
    elseif newstate == "mcpet" then
        print("Curse your sudden but inevitable betrayal, kitty!") -- Your pet is hostile to you.
    end
]])



<Frame name="MyStateFrame" inherits="SecureHandlerStateTemplate" parent="UIParent" protected="true">
 <Attributes>
   <Attribute name="_onstate-show" value="if newstate == 'show' then self:Show() else self:Hide() end" />
   <Attribute name="_onstate-enable" value="if newstate == 'show' then self:Enable() else self:Disable() end" />
 </Attributes>
 <Scripts>
  <OnLoad>
   SecureHandler_OnLoad(self); -- Our OnLoad handler overwrites this one, so execute it now.
   RegisterStateDriver(self, "show", "[button:2] show; hide");
   --RegisterStateDriver(self, "enable", "[button:2] show; hide");
  </OnLoad>
 </Scripts>
 <Size x="64" y="64"/>
 <Anchors><Anchor point="CENTER"/></Anchors>
 <Layers><Layer level="OVERLAY">
  <Texture name="$parentTex" file="Icons\Temp" setAllPoints="true" />
 </Layer></Layers>
</Frame>





