
--[[
	Name alternatives:
FreeCursorMode (normal) / FreeCameraMode (LeftButton) / MouselookMode (RightButton).
FreeCameraMode = LookAroundMode = CameraMode
FreeCursorMode = MouseCursorMode = CursorMode, for short.
MouseTurn = MouselookMode = RightClick
ActionMode = ActionCameraMode = MouselookMode without pressing RightButton. Riding the hypetrain of ActionCombat (not in wow...) and ActionCamera (this is a thing, try DynamicCam addon).
ActionControls..  found it..  ImmersiveActionControls  ImmersiveActionMode  ImmersiveAction
ImmersiveControls  ImmersionControls  ImmersionCamera

Actually you can be in CursorMode while in ActionMode by pressing RightButton.
Pressing LeftButton will go into CameraMode or start moving (MoveAndSteer) in ActionMode.

ImmersiveAction
CameraMode
MouseCameraMode-MouseCursorMode-MouselookMode
Mouselook
https://en.wikipedia.org/wiki/Free_look

	Inspired by:
Immersive Immersive Combat for Guild Wars 2    http://wesslen.org/ICM/
ImmersiveAction addon
Mouse_Look_Lock     https://github.com/DWishR/Mouse-Look-Lock
MouselookHandler    https://github.com/meribold/MouselookHandler
ConsolePort         https://github.com/seblindfors/ConsolePort

https://wow.curseforge.com/projects/combat-mode
https://www.wowinterface.com/downloads/info24776-ImmersiveActionReborn.html
https://wow.curseforge.com/projects/mouse-look-lock
-- It also causes the mouse buttons to remap to movement (forward and backward) keys to match the configuration found in Dark Age of Camelot.
https://wow.curseforge.com/projects/kiki-utils
-- Mouselook : Real DAoC mouse look mode. Key1 switch to and from Mouselook on each press. Hold Key2 to move the camera (when in Mouselook mode). In Mouselook mode, Button1 and Button2 are remapped to MoveForward and MoveBackward. Mouselook mode does NOT break follow mode.
https://wow.curseforge.com/projects/mouselookhandler
https://wow.curseforge.com/projects/mouselook
https://wow.curseforge.com/projects/mouselook-binding
https://wow.curseforge.com/projects/mouse-combat

Targeting without mouse press:  cast spell when releasing bound key.
https://wow.curseforge.com/projects/aoeonrelease
https://www.mmo-champion.com/threads/2110112-GW2-Style-Ground-Targeted-Casting

Basic comparison:
--
MouselookHandler monitors/hooks the two mouse buttons:  TurnOrAction, CameraOrSelectOrMove
	Credits for learning about these commands and hooking them goes to its authors  meribold (Lukas Waymann) and pwoodworth (Patrick Woodworth).
  Shows the cursor if SpellIsTargeting(),  or if any of 2 frames pop up:  MovieFrame.CloseDialog, CinematicFrameCloseDialog
  Has a config dialog for MouselookOverrideBindings, and a Lua editbox where you can write your own addon.
Mouse-Look-Lock has an extensive list of monitored frames, tediously collected by hand.
	Shows the cursor if CursorHasItem() or a window pops up.
	Credits for the framelist goes to its author  Trimble Epic.
  Scans each frame every 0.2 seconds (MouseLook_UpdateFrequency), looking them up in _G.  UnmouseableFrameOnScreen() comes from there.
	It also prevents switching to Mouselook - i think - when mouse is over some frames like ChatFrame buttons, BuffFrame, UnitFrame, PetActionBarFrame.
CombatMode introduced interacting and targeting nearby npcs with the same button, without moving the mouse, like in any modern mmo designed for user experience (UX).
	Credits for the implementation idea for InteractNearest goes to its author  Justice7ca.
	Shows the cursor if CursorHasItem() or SpellIsTargeting().
	Also monitors frames using UnmouseableFrameOnScreen() on every OnUpdate().

kiki-utils
ConsolePort

Credits also go to:
--
SuppressRightClick and its contributors  Maunotavast, tynstar9, Urzulan.  See credits/SuppressRightClick.txt for details and forum logs.
AoEonRelease for the most precisely crafted and researched code i've seen in addons. It does brainsurgery on the crooked SecureHandlers. Kudos for the perfectionism.
--]]


--[[
/targetenemy [noharm][dead]
/target[harm][dead]
-> InteractTarget -> loot?

/dump GetBindingByKey('BUTTON1'), GetBindingByKey('BUTTON2')
/dump GetBindingKey('CAMERAORSELECTORMOVE'), GetBindingKey('TURNORACTION'), GetBindingKey('TARGETNEARESTFRIEND')
Reset to default:
/run ImmersiveAction.ResetMouseButton12Bindings()
/run SetBinding('BUTTON1','CAMERAORSELECTORMOVE') SetBinding('BUTTON2','TURNORACTION')
Additional:
/run SetBinding('BUTTON4','MOVEANDSTEER') SetBinding('BUTTON5','COMBATMODE_ENABLE')
/run SetBinding('ALT-BUTTON4','TOGGLEAUTORUN')
My favourite:
/run SetBinding('BUTTON1','MOVEANDSTEER') SetBinding('ALT-BUTTON1','CAMERAORSELECTORMOVE') SetBinding('BUTTON2','TURNORACTION') SetBinding('BUTTON4','TOGGLEAUTORUN')

Debug:
/dump ImmersiveAction.Config.optionsFrame
--]]


-- ADDON main: Ace libs, initialization, settings, bindings
local G, ADDON_NAME, ADDON = _G, ...
local IA = G.ImmersiveAction or {}
G.ImmersiveAction = LibStub("AceAddon-3.0"):NewAddon(IA, "ImmersiveAction", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0")
if IA.SetRealAddonName then  IA:SetRealAddonName(...)  end
IA.name = 'ImmersiveAction'

-- Export to _G.IA for DEVMODE.
if G.DEVMODE then  G.IA = G.IA or IA  end
local Log = IA.Log or {}  ;  IA.Log = Log

-- GLOBALS:
-- Upvalued Lua globals: 
-- Used from _G:  



--------------------------
-- Addon loading events
--------------------------

-- Initial state:
-- IA.activeCommands.ActionMode = nil
-- IA.activeCommands.ActionModeRecent = nil


function IA:OnInitialize()
	-- Run on this addon's ADDON_LOADED event.
	Log.Init('  ImmersiveAction:OnInitialize()')
	self:HookCommands()
	-- self:HookUpFrames()		-- is it necessary before OnEnable() calling it again?
	self:RegisterChatCommand("ia", "ChatCommand")
	self:RegisterChatCommand("immersiveaction", "ChatCommand")
	
	--[[
	Use one profile called 'Default' for all characters originally.
	Name of default profile can be changed with setting  profileKeys['Default'].
	To have character-specific profiles when creating/initializing a new character:
	/run  ImmersiveActionSV.profileKeys.Default = false
	--
	local defaultProfile = ImmersiveActionSV  and  ImmersiveActionSV.profileKeys  and  ImmersiveActionSV.profileKeys.Default
	if  defaultProfile == nil  then  defaultProfile = true  end		-- false to have character-specific profiles
	self.db = LibStub("AceDB-3.0"):New("ImmersiveActionSV", self.defaultSettings, defaultProfile)
	--]]
	self.db = LibStub("AceDB-3.0"):New("ImmersiveActionSV", self.defaultSettings, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
	-- self.db.RegisterCallback(self, "OnDatabaseShutdown", "OnLogout")
	
	-- Initial UpdateOverrideBindings() run in OnEnable()
	-- self:ProfileChanged()
end	


function IA:OnEnable()
	-- Run on PLAYER_LOGIN, before PLAYER_ENTERING_WORLD
	-- frame sizes and positions are loaded before this event
	Log.Init('  ImmersiveAction:OnEnable()')

	-- UpdateOverrideBindings() is called when key bindings change.
	self:UpdateOverrideBindings()
	self:RegisterBucketEvent('UPDATE_BINDINGS', 0.3, 'UpdateOverrideBindings')
	self.WorldClickHandler:Enable(true)
	self.OverrideBindings:Enable(true)
	self.InteractNearest:Enable(true)

	self:SetActionMode(self.db.profile.enabledOnLogin, true)

	-- Find frames now, after addons loaded.
	self:HookUpFrames()
	-- Find missing frames when delayed loading any addon.
	self:RegisterEvent('ADDON_LOADED')

	-- Monitor Shift/Ctrl/Alt in CommandHooks.lua.
	self:RegisterCommandEvents(true)
	-- Targeting and questing shows cursor.
	self:RegisterWindowEvents(true)
	
	self.Config:InitOptionsFrame()
end


function IA:OnDisable()
	Log.Init('  ImmersiveAction:OnDisable()')
	-- Called when the addon is disabled

	self.activeCommands.ActionMode = false
	self.activeCommands.ActionModeRecent = nil

	self:UnregisterEvent('ADDON_LOADED')

	-- Monitor Shift/Ctrl/Alt in CommandHooks.lua.
	self:RegisterCommandEvents(false)
	-- Targeting and questing shows cursor.
	self:RegisterWindowEvents(false)

	-- Disable UpdateOverrideBindings().
	self:UnregisterBucketEvent('UPDATE_BINDINGS')
	self.WorldClickHandler:Enable(false)
	self.OverrideBindings:Enable(false)
	self.InteractNearest:Enable(false)
end


function IA:ADDON_LOADED(event, addonName)
	-- registered for event after PLAYER_LOGIN fires:
	-- static loaded addons already received it
	-- only delay-loaded addons will trigger
	-- ex.: Blizzard_BindingUI -> KeyBindingFrame
	Log.Init('  ImmersiveAction:ADDON_LOADED('.. IA.colors.green .. addonName ..'|r)')
	self:HookUpFrames()
end


function IA:ProfileChanged()
	-- Update loaded user binding overrides.
	-- self.UserBindings:UpdateUserBindings()
	self:UpdateOverrideBindings()
end


-- UpdateOverrideBindings() is called when key bindings change.
function IA:UpdateOverrideBindings(event)
	self.WorldClickHandler:UpdateOverrideBindings()
	self.OverrideBindings:UpdateOverrideBindings()
	self.InteractNearest:UpdateOverrideBindings()
end



----------------------
-- Binding settings
----------------------

function IA.ResetMouseButton12Bindings()
	SetBinding('BUTTON1'      ,'CAMERAORSELECTORMOVE')
	SetBinding('BUTTON2'      ,'TURNORACTION')
	SetBinding('ALT-BUTTON1'  ,nil)
	SetBinding('ALT-BUTTON2'  ,nil)
	SetBinding('CTRL-BUTTON1' ,nil)
	SetBinding('CTRL-BUTTON2' ,nil)
	SetBinding('SHIFT-BUTTON1',nil)
	SetBinding('SHIFT-BUTTON2',nil)
	SetBinding('ALT-CTRL-BUTTON1' ,nil)
	SetBinding('ALT-CTRL-BUTTON2' ,nil)
	SetBinding('ALT-SHIFT-BUTTON1',nil)
	SetBinding('ALT-SHIFT-BUTTON2',nil)
	SetBinding('CTRL-SHIFT-BUTTON1',nil)
	SetBinding('CTRL-SHIFT-BUTTON2',nil)
	SetBinding('ALT-CTRL-SHIFT-BUTTON1',nil)
	SetBinding('ALT-CTRL-SHIFT-BUTTON2',nil)
	-- Exhaustive.
end




----------------------
-- Chat command  /ia  /immersiveaction
----------------------

function IA:ChatCommand(input)
    if not input or input:trim() == "" then
        InterfaceOptionsFrame_OpenToCategory(self.Config.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.Config.optionsFrame)
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("ia", "ImmersiveAction", input)
    end
end





----------------------
-- Shared functions
----------------------

local LibShared = G.LibShared
LibShared.SetScript = LibShared.SetScript or {}

--- LibShared.SetScript.OnEvent(frame):  Set a default 'OnEvent' script for the frame.
-- It dispatches events to methods on the frame with the same name as the event.
-- Like:  frame:ADDON_LOADED(eventName, addonName)  and  frame:PLAYER_LOGIN('PLAYER_LOGIN')  and so on.
--
LibShared.SetScript.OnEvent = LibShared.SetScript.OnEvent  or  function(frame, eventName, ...)  if frame[eventName] then  frame[eventName](frame, eventName, ...)  end end



--- CreateMacroButton(name, macrotext, label)
-- @return a Button that runs macrotext when clicked. Useable to create bindings that run a macro.
-- @param name  Identifier of binding.
-- @param macrotext  Macro code to execute when clicked.
-- @param label  The text visible on the builtin keybinding panel.
--
-- Suggested usage (replace the macrotext and the label "Clear target"):
-- LibShared.Require.CreateMacroButton('ClearTargetButton', '/cleartarget', "Clear target")
-- Then create a command binding with it in Bindings.xml (replace "ClearTargetButton"):
-- <Binding name="CLICK ClearTargetButton:LeftButton"></Binding>
--
LibShared.Define.CreateMacroButton = function(name, macrotext, label)
	local button = CreateFrame('Button', name, UIParent, 'SecureActionButtonTemplate')
	button:Hide()
	button:SetAttribute('type', 'macro')
	button:SetAttribute('macrotext', macrotext)
	button.binding = 'CLICK '..name..':LeftButton'
	if label then  G['BINDING_NAME_'..button.binding] = label  end
	return button
end




LibShared.MapButtonToKey = LibShared.MapButtonToKey  or  setmetatable({
	-- Necessary special cases:
	LeftButton   = 'BUTTON1',
	RightButton  = 'BUTTON2',
	MiddleButton = 'BUTTON3',
	-- Common:
	Button4 = 'BUTTON4',
	Button5 = 'BUTTON5',
	-- 8 fields are preallocated, these are free in terms of memory:
	-- BUTTON6 = 'Button6',
	-- BUTTON7 = 'Button7',
	-- BUTTON8 = 'Button8',
},{
	__index = function(self, Button)  return 'BUTTON'..Button:sub(7)  end
	-- __index = function(self, Button)  return Button:upper()  end
})
-- for i=4,8 do  LibShared.MapButtonToKey['Button'..i] = 'BUTTON'..i  end
-- for i=4,16 do  LibShared.MapButtonToKey['Button'..i] = 'BUTTON'..i  end
-- for i=4,31 do  LibShared.MapButtonToKey['Button'..i] = 'BUTTON'..i  end



local IsAltKeyDown,IsControlKeyDown,IsShiftKeyDown  =  IsAltKeyDown,IsControlKeyDown,IsShiftKeyDown

LibShared.IsModifierPressed = LibShared.IsModifierPressed  or  {
	ALT   = IsAltKeyDown,
	CTRL  = IsControlKeyDown,
	SHIFT = IsShiftKeyDown,
}


--[[
LibShared.IsModifierPressedExt = LibShared.IsModifierPressedExt  or  {
	ALT   = G.IsAltKeyDown,
	CTRL  = G.IsControlKeyDown,
	SHIFT = G.IsShiftKeyDown,
	LALT   = G.IsLeftAltKeyDown,
	LCTRL  = G.IsLeftCtrlKeyDown,
	LSHIFT = G.IsLeftShiftKeyDown,
	RALT   = G.IsRightAltKeyDown,
	RCTRL  = G.IsRightCtrlKeyDown,
	RSHIFT = G.IsRightShiftKeyDown,
}
--]]


LibShared.IsModifiedBinding = LibShared.IsModifiedBinding  or  {
	[''] = function()  return true  end,
	['ALT-']   = IsAltKeyDown,
	['CTRL-']  = IsControlKeyDown,
	['SHIFT-'] = IsShiftKeyDown,
	['ALT-CTRL-']   = function()  return IsAltKeyDown() and IsControlKeyDown()  end,
	['ALT-SHIFT-']  = function()  return IsAltKeyDown() and IsShiftKeyDown()  end,
	['CTRL-SHIFT-'] = function()  return IsControlKeyDown() and IsShiftKeyDown()  end,
	['ALT-CTRL-SHIFT-'] = function()  return IsAltKeyDown() and IsControlKeyDown() and IsShiftKeyDown()  end,
}




local ModifierBinaryIdx = {
	[0] = '',       -- Zero-indexed array.
	'ALT-',         -- 1
	'CTRL-',        -- 2
	'ALT-CTRL-',    -- 1+2
	'SHIFT-',       -- 4
	'ALT-SHIFT-',   -- 1+4
	'CTRL-SHIFT-',  -- 2+4
	'ALT-CTRL-SHIFT-',
}

--- GetBindingModifier():  Get the currently pressed modifiers in the bindings format:  'ALT-CTRL-SHIFT', and variants.
-- @return  '' / 'ALT-' / 'CTRL-' / 'SHIFT-' / 'ALT-CTRL-' / 'ALT-SHIFT-' / 'CTRL-SHIFT-' / 'ALT-CTRL-SHIFT-'
-- The order of modifiers is strictly ALT, CTRL, SHIFT - increasing alphabetical.
--
LibShared.GetBindingModifier = LibShared.GetBindingModifier  or  function()
	local idx = 0
	if IsAltKeyDown() then      idx = 1  end
	if IsControlKeyDown() then  idx = idx + 2  end
	if IsShiftKeyDown() then    idx = idx + 4  end
	return ModifierBinaryIdx[idx]
end



local GetBindingModifier,MapButtonToKey,GetBindingByKey  =  LibShared.GetBindingModifier, LibShared.MapButtonToKey, G.GetBindingByKey

LibShared.GetBindingByButton = LibShared.GetBindingByButton  or  function(button)
	local mod,key = GetBindingModifier(), MapButtonToKey[button]
	local command = GetBindingByKey(mod..key)
	return command,mod,key
end




--[[
-- A more readable version, that adds 3 numbers, while the previous adds only those pressed.
LibShared.GetBindingModifier = LibShared.GetBindingModifier  or  function()
	local idx =
		(IsAltKeyDown() and 1 or 0) +
		(IsControlKeyDown() and 2 or 0) +
		(IsShiftKeyDown() and 4 or 0)
	return ModifierBinaryIdx[idx]
end

-- This joins only those that are pressed.
LibShared.GetBindingModifier = LibShared.GetBindingModifier  or  function()
	local mod = ''
	if IsAltKeyDown() then  mod = 'ALT-'  end
	if IsControlKeyDown() then  mod = mod..'CTRL-'  end
	if IsShiftKeyDown() then  mod = mod..'SHIFT-'  end
	return mod
end

-- This joins 3 strings in any case.
LibShared.GetBindingModifier3 = LibShared.GetBindingModifier3  or  function()
	local mod = 
		(IsAltKeyDown() and 'ALT-' or '') ..
		(IsControlKeyDown() and 'CTRL-' or '') ..
		(IsShiftKeyDown() and 'SHIFT-' or '')
	return mod
end
--]]



