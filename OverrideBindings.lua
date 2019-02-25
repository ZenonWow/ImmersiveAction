local _G, ADDON_NAME, _ADDON = _G, ...
local IA = _G.ImmersiveAction or {}  ;  _G.ImmersiveAction = IA
local Log = IA.Log
local Log = IA.Log or {}  ;  IA.Log = Log

-- Used from LibShared:
local ipairsOrOne,packOrOne,pairsOrNil = LibShared.Import('ipairsOrOne,packOrOne,pairsOrNil,', IA)




------------------------------
-- Declare the command overrides in specific modes
-- OverridesIn[mode][fromCmd] = toCmd
------------------------------

local OverridesIn = { ActionMode = {}, AutoRun = {}, InteractNearest = {}, Mouselook = {}, General = {} }
IA.OverridesIn = OverridesIn

--- INTERACTMOUSEOVER --> TURNORACTION -- Invert Mouselook.
-- InteractMouseover is useless without cursor (in Mouselook mode).
-- Typically pressed if the user wants the mouse to select something so release the cursor with RightButton's command.
-- Only the first binding supported.
OverridesIn.Mouselook.INTERACTMOUSEOVER = 'TURNORACTION'

--- MOVEANDSTEER --> MOVEFORWARD for AutoRun to fix the abrupt stop.
-- MoveAndSteerStop() stops AutoRun, which is very disturbing when turning with MoveAndSteer while in AutoRun mode.
-- Override to TurnOrAction in AutoRun mode to avoid this annoyance. This is effective even out of ActionMode.
OverridesIn.AutoRun.MOVEANDSTEER = 'TURNORACTION'  -- Note: set priority over ActionMode's override, or skip that.
-- Or override with MoveForward in ActionMode, but that's no help out of ActionMode.
-- OverrideBindings.OverridesIn.ActionMode.MOVEANDSTEER = 'MoveForward'

-- TODO: Should only override MouseButton bindings.
-- Override at all times, losing Mouselook, and patch it back in  :SetCommandState()
--OverridesIn.General.MOVEANDSTEER = 'MOVEFORWARD'
-- Override in Mouselook, resulting in stuck Mouselook, and unstuck in  :SetCommandState()
--OverridesIn.Mouselook.MOVEANDSTEER = 'MOVEFORWARD'

--[[ ExpectedMouselook() now inverts Mouselook when RightButton is pressed, solving this issue.
-- RightButton = TURNORACTION:  in ActionMode Turning is always on making RightButton useless
--> change behavior with :ExpectedMouselook()  or  override with:
-- OverrideBindings.OverridesIn.ActionMode.TURNORACTION = 'INTERACTNEAREST'    -- Peaceful
-- if GetCVarBool('interactOnLeftClick') then
	-- OverrideBindings.OverridesIn.ActionMode.TURNORACTION = 'TargetNearestEnemy'
-- end    -- Combatant
--]]

--[[ ExpectedMouselook() also handles this, in a combat-safe mode, without bindings.
-- BUTTON1 = CAMERAORSELECTORMOVE: Select does nothing when mouse is hidden -> override with TargetNearestFriend.
-- Note: Camera needs disabling Mouselook in MouseDown script. Move (BUTTON1+BUTTON2) is pointless in this state.
-- OverrideFrames.Mouselook:OverrideCommand('CameraOrSelectOrMove', 'TargetNearestFriend')
-- if GetCVarBool('interactOnLeftClick') then  OverrideFrames.Mouselook:OverrideCommand('CameraOrSelectOrMove', 'INTERACTNEAREST')  end
--]]




------------------------------
-- User bindings frame
------------------------------

local UserBindings = CreateFrame('Frame')
IA.UserBindings = UserBindings
UserBindings:Hide()
UserBindings.cmdKeyMaps = {}


function IA:SetUserBinding(mode, key, command)
	self.db.profile['bindingsIn'..mode][key] = value
	UserBindings:OverrideOneBinding(mode, key, command)
end


function UserBindings:OverrideOneBinding(mode, newKey, command)
	if newKey=='' then  newKey = nil  end

	local cmdKeyMap = self.cmdKeyMaps[mode]
	if not cmdKeyMap then  cmdKeyMap = {} ; self.cmdKeyMaps[mode] = cmdKeyMap  end

	local oldKey = cmdKeyMap[toCmd]
	if oldKey then  SetOverrideBinding(self, false, oldKey, nil)  end
	cmdKeyMap[toCmd] = newKey
	SetOverrideBinding(self, false, newKey, toCmd)
end



function UserBindings:OverrideBindings(mode, keyBindings)
	if not keyBindings then  return  end

	local cmdKeyMap = self.cmdKeyMaps[mode]
	if not cmdKeyMap then  cmdKeyMap = {} ; self.cmdKeyMaps[mode] = cmdKeyMap  end

	-- Set new overrides
	for newKey,toCmd in pairs(keyBindings) do  if toCmd~='' then
		if newKey=='' then  newKey = nil  end
		local oldKey = cmdKeyMap[toCmd]
		LibShared.softassertf(not oldKey, "UserBindings:OverrideBindings(): command %s already registered, overwriting:  %s  ->  %s", toCmd, oldKey, newKey)
		cmdKeyMap[toCmd] = newKey
		print("UserBindings: SetOverrideBinding(.., "..newKey..", "..tostring(toCmd))
		SetOverrideBinding(self, false, newKey, toCmd)
	end end -- for for
end



function IA:OverrideUserBindings(mode)
	UserBindings:OverrideBindings(mode, self.db.profile['bindingsIn'..mode])
end


function IA:UpdateUserBindings()
	print("ImmersiveAction:UpdateUserBindings()")
	-- First happens in response to ADDON_LOADED. Later on ProfileChanged()  and  when a binding is changed in Config.
	--[[
	MouselookStop() won't interrupt command keys that are pressed, i.e. received "down" event, but not "up"
	Those commands will not run for the "up" event if their binding is changed, instead
	the new binding will receive the "up" event without a "down" event.
	This results in unexpectedly entering or leaving ImmersiveAction when rebinding a command that changes ImmersiveAction.
	--]]
	local wasMouselooking = _G.IsMouselooking()
	if wasMouselooking then
		-- Log.Anomaly('ImmersiveAction:UpdateUserBindings() while IsMouselooking() could cause stuck keys, not updating bindings.')
		-- return
		Log.Anomaly('ImmersiveAction:UpdateUserBindings() while IsMouselooking() could cause stuck keys, temporarily disabling Mouselook.')
		IA.MouselookStop()
	end

	ClearOverrideBindings(UserBindings)
	self:OverrideUserBindings('General')
	self:OverrideUserBindings('ActionMode')

	-- Modifiers (SHIFT/CTRL/ALT) to turn on/off ActionMode.
	-- Currently the ModifiedClick is not used, only the profile.modifiers.* setting.
	-- SetModifiedClick('ActionModeEnable', profile.modifiers.enableModifier)
	-- SetModifiedClick('ActionModeDisable', profile.modifiers.disableModifier)

	-- self:ResetState()
	if wasMouselooking then  IA.MouselookStart()  end
end






-------------------------------
-- Command override bindings frame
-------------------------------

local OverrideBindings = CreateFrame('Frame')
IA.OverrideBindings = OverrideBindings
LibShared.SetScript.OnEvent(OverrideBindings)

OverrideBindings:Hide()
OverrideBindings.cmdKeys = {}
OverrideBindings.MouselookOverrides = {}


function OverrideBindings:CaptureBindings(mode, overrides)
	local cmdKeys = self.cmdKeys
	for fromCmd,toCmd in pairs(overrides) do
		if not cmdKeys[fromCmd] then
			-- Keys to override when enabled.
			cmdKeys[fromCmd] = packOrOne( GetBindingKey(fromCmd) )
		end
	end
end


function OverrideBindings:OverrideCommands(overrides, enable)
	for fromCmd,toCmd in pairs(overrides) do
		if not enable then  toCmd = nil  end
		for i,key in ipairsOrOne(self.cmdKeys[fromCmd]) do
			SetOverrideBinding(self, priority, key, toCmd)
		end
	end
end

--[[
-- Store  key -> toCmd  in keyOverrides  just like InteractNearest:CaptureBindings().
function OverrideBindings:CaptureBindings2(mode, overrides)
	local keyOverrides = {}
	for fromCmd,toCmd in pairs(overrides) do
		local keys = { GetBindingKey(fromCmd) }
		for i,key in ipairs(keys) do
			LibShared.softassert(not keyOverrides[key], "Duplicate key override: OverridesIn."..mode.."."..key)
			keyOverrides[key] = toCmd
		end
	end
	self.modeKeyOverrides[overrides] = keyOverrides
end


function OverrideBindings:OverrideCommands2(overrides, enable)
	local keyOverrides = self.modeKeyOverrides[overrides]
	for key,toCmd in pairs(keyOverrides) do
		if not enable then  toCmd = nil  end
		SetOverrideBinding(self, priority, key, toCmd)
	end
end
--]]


function OverrideBindings:ClearMouselookOverrideBindings()
	for key,toCmd in pairsOrNil(self.MouselookOverrides) do
		_G.SetMouselookOverrideBinding(key, nil)
	end
	wipe(self.MouselookOverrides)
end


function OverrideBindings:SetMouselookOverrideBindings(fromCmd, toCmd)
	-- Keys to override when enabled.
	for i,key in ipairsOrOne(self.cmdKeys[fromCmd]) do
		if LibShared.softassert(not self.MouselookOverrides[key]) then
			LibShared.softassertf(fromCmd~='TURNORACTION' and fromCmd~='TARGETSCANENEMY', "SetMouselookOverrideBindings():  overriding bindings of %q to %q will cause stucking in Mouselook mode.", fromCmd, toCmd)
			self.MouselookOverrides[key] = toCmd
			_G.SetMouselookOverrideBinding(key, toCmd)
		end
	end
end




------------------------------
-- Enable the overrides in specific modes.
------------------------------

function IA:OverrideCommandsIn(mode, enable)
	print('  ImmersiveAction:OverrideCommandsIn('..mode..', '..IA.colorBoolStr(enable, true)..')')
	if InCombatLockdown() then
		Log.State("ImmersiveAction:OverrideCommandsIn() ignored:  Can't update bindings when InCombatLockdown()")
	else
		if enable==nil then  enable = self.commandState[mode]  end
		OverrideBindings:OverrideCommands(OverridesIn[mode], enable)
		if mode=='ActionMode' then  self:OverrideUserBindings(mode, enable)  end
	end
end


-- Disable OverrideBindings before combat.
function OverrideBindings:PLAYER_REGEN_DISABLED(event)
	self:OverrideCommandsIn('ActionMode'   , false)
	self:OverrideCommandsIn('AutoRun'      , false)
end

-- Enable OverrideBindings after combat, depending on IA.commandState[mode].
function OverrideBindings:PLAYER_REGEN_ENABLED(event)
	self:OverrideCommandsIn('ActionMode')
	self:OverrideCommandsIn('AutoRun')
end

function OverrideBindings:Enable(enable)
	if  not self.enable == not enable  then  return nil  end
	self.enable = enable

	-- IA.commandState.OverrideBindings = enable
	if enable then
		self:RegisterEvent('PLAYER_REGEN_DISABLED')
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
		self:PLAYER_REGEN_ENABLED('Enable(true)')
	else
		self:UnregisterEvent('PLAYER_REGEN_DISABLED')
		self:UnregisterEvent('PLAYER_REGEN_ENABLED')
		self:PLAYER_REGEN_DISABLED('Enable(false)')
	end
	return true
end




------------------------------
-- Update when bindings change.
------------------------------

function OverrideBindings:UpdateOverrideBindings(event)
	print("OverrideBindings:UpdateOverrideBindings()")

	ClearOverrideBindings(OverrideBindings)
	OverrideBindings:ClearMouselookOverrideBindings()

	-- Capture bindings of commands for later overriding.
	for mode,overrides in pairs(OverridesIn) do
		OverrideBindings.CaptureBindings(mode, overrides)
	end

	-- Mouselook bindings are activated by the game.
	for fromCmd,toCmd in pairs(OverridesIn.Mouselook) do
		OverrideBindings:SetMouselookOverrideBindings(fromCmd, toCmd)
	end
end


function OverrideBindings:GetBoundKeys(overrides)
	for fromCmd,toCmd in pairs(overrides) do
		local keys = self.cmdKeys[fromCmd]
		if keys then  return keys  end
	end
	return nil
end






-------------------------------
-- Experiment: SecureHandler hooking WorldFrame to capture mouse button commands.
-- Result:  WorldFrame has no OnClick handler (not a Button), and SecureHandlerClickTemplate don't support OnMouseDown/OnMouseUp handlers.
-- Trying SecureHandlerMouseUpDownTemplate.
-------------------------------

---------- Ctrl+LeftClick UP:  what is Ctrl-B1-UP stickycamera??
---------- CameraOrSelectOrMoveStop(IsModifiedClick("STICKYCAMERA"));


-- Secure wrapper function WorldFrame_OnMouseDown_PreSnippet(self, button, down)
-- If CameraButton (LeftButton) is pressed then rebinds TurnBUTTON (BUTTON2) to AUTORUN.
-- In the secure environment:  owner == WorldClickHandler, self == WorldFrame  and  control == owner, i guess, but no code or documentation confirms.
local WorldFrame_OnMouseDown_PreSnippet = [===[
	print(" WorldFrame_OnMouseDown_PreSnippet("..button..") ")
	local key = MapButtonToKey[button]
	Pressed[#Pressed+1] = key
	Pressed[key] = #Pressed

	if Rebound[key] then  return  end
	if  key == TurnBUTTON  and  Pressed[CameraBUTTON]  then
		Rebound[key] = 'AUTORUN'
		owner:SetBinding(true, key, 'AUTORUN')
	end
end
]===]


-- Credits for coming up with a solution to the accidental rightclick go to:
-- Maunotavast-Zenedar    https://worldofwarcraft.com/en-gb/character/zenedar/Maunotavast
-- SuppressRightClick addon    https://wow.curseforge.com/projects/src
-- tynstar9    https://wow.curseforge.com/members/tynstar9    jens dot b at web dot de
-- Urzulan     https://wow.curseforge.com/members/Urzulan
--
-- This combines version 0.2 where rightclick is disabled only over mouseover units - so game objects can be clicked - with:  RegisterStateDriver(.., "[@mouseover,exists]1;0")
-- And version 0.3 where a second click in DoubleClickDuration allows the rightclick to go through and interact, independent of mouseover.
-- Also prevents accidental pulls out-of-combat by always disabling single-click RightButton.
-- To interact:  press Ctrl-RightButton - configurable with:  SetModifiedClick('Interact', 'ALT')  or  'SHIFT'  or  'CTRL-SHIFT'  or so.
-- Or bind a dedicated button to INTERACTMOUSEOVER:  SetBinding('INTERACTMOUSEOVER', 'CTRL-BUTTON2')
-- Or doubleclick. Spamming rightclick is also possible: every consecutive click within 0.3 seconds goes through. No clicks are skipped every 0.3 seconds.
--
-- How it works:
-- If TurnButton (RightButton) is released over a unit (mouseover) then
-- v0.2:  Rebinds TurnBUTTON (BUTTON2) to TurnOrActionHijack, avoiding the Interact action.
-- This happens before the MouseDown event is mapped to the standard TurnOrAction command. Post-release the hijack is disabled.
-- v0.3:  Simply calls MouselookStop() - an independent aspect in concept, but it tracks the pressed state of TurnOrAction.
-- Turning it off makes wow think the button was not pressed, and the release event is just a phantom signal.
-- Curious thing is the HookScript runs after the builtin OnMouseUp handler, so what comes even later that actually handles the key release?
-- v4:  Test if simply consuming the MouseDown event with `return true` is sufficient to fix this issue.
-- MouselookStop() is still necessary, otherwise it gets stuck. UpdateMouselook() can do it, but the trigger of
-- TurnOrActionStop() is also eliminated, confusing the StateHandler ExpectedMouselook(). Can be replace with  IA:CommandHook('TurnOrAction', false, 'TurnOrActionStop')
-- Verdict:  MouselookStop() is more compatible with hooking TurnOrActionStop().
-- This implementation uses the MouselookStop() method. Will work, until bliz fixes the design flaw of TurnOrActionStop(), present since 2004.
--
-- Secure wrapper function WorldFrame_OnMouseUp_PreSnippet(self, button, down)
local WorldFrame_OnMouseUp_PreSnippet = [===[
	print(" WorldFrame_OnMouseUp_PreSnippet("..button..") ")
	local key = MapButtonToKey[button]
	
	-- Mark key released in Pre snippet:  UP event handlers will see the state as released.
	local index = Pressed[key]
	Pressed[key] = nil
	Pressed[index] = false
	
	-- Clear released keys from the end of the list until found a pressed key.
	if index == #Pressed then  while Pressed[index]==false  do
		Pressed[index] = nil
		index = index - 1
	end end -- if while

	if  key == TurnBUTTON  and  not Rebound[key]  and  UnitExists('mouseover')  and  not IsModifiedClick('Interact')  then
		local now, last = owner:GetTime(), LastTurnClick
		LastTurnClick = now
		if DoubleClickInterval < now-last then
			-- Rebound[key] = 'TurnOrActionHijack'
			-- owner:SetBinding(false, key, 'TurnOrActionHijack')
			owner:CallMethod('MouselookStop')    -- Hack TurnOrActionStop() into believing it was not pressed.
			-- return true
		end
	end
]===]
-- LastTurnClick is updated for doubleclicks too, so as long as the user lands clicks in 0.3 sec, all clicks will Interact.
-- Spamming clicks still works, but a single click is prevented from an accidental pull or targeting.


-- Secure wrapper function WorldFrame_OnMouseUp_PostSnippet(self, button, down)
local WorldFrame_OnMouseUp_PostSnippet = [===[
	print(" WorldFrame_OnMouseUp_PostSnippet("..button..") ")

	local key = MapButtonToKey[button]
	if Rebound[key] then
		Rebound[key] = nil
		owner:ClearBinding(key)
	end
]===]



local WorldClickHandler = CreateFrame('Frame', nil, nil, 'SecureHandlerMouseUpDownTemplate')
IA.WorldClickHandler = WorldClickHandler
_G.WCH = WorldClickHandler    -- Export for DEBUG.


WorldClickHandler.InitSnippet = [===[
	-- I will definitely forget to initialize this:
	LastTurnClick, DoubleClickInterval = 0, 0.3
	Pressed = newtable()
	Rebound = newtable()

	MapButtonToKey = newtable()
	MapButtonToKey.LeftButton = BUTTON1
	MapButtonToKey.RightButton = BUTTON2
	MapButtonToKey.MiddleButton = BUTTON3
	for i=4,31 do  MapButtonToKey['Button'..i] = 'BUTTON'..i  end
]===]


function WorldClickHandler:InitSecureHandler()
	local handler = self    -- For clarity.
	-- Init "global" variables in secure environment.
	-- handler:SetAttribute('_set', " local name,value=... ; _G[name] = value ")

	handler.MouselookStop = IA.MouselookStop
	handler:Execute(WorldClickHandler.InitSnippet)
	handler.Env = _G.GetManagedEnvironment(handler)

	-- handler:WrapScript(WorldFrame, 'OnMouseDown', prePressBody, nil)
	-- handler:WrapScript(WorldFrame, 'OnMouseUp'  , preReleaseBody, postReleaseBody)
	-- Same with less calls:
	SecureHandlerWrapScript(WorldFrame, 'OnMouseDown', handler, WorldFrame_OnMouseDown_PreSnippet, nil)
	SecureHandlerWrapScript(WorldFrame, 'OnMouseUp'  , handler, WorldFrame_OnMouseUp_PreSnippet, WorldFrame_OnMouseUp_PostSnippet)
	
	handler:UpdateDoubleClickInterval()
	handler:UpdateOverrideBindings()
end


function WorldClickHandler:DisableHandler()
	self:UnwrapScript(WorldFrame, 'OnMouseDown')
	self:UnwrapScript(WorldFrame, 'OnMouseUp')
end


function WorldClickHandler:UpdateDoubleClickInterval()
	handler:Execute(" DoubleClickInterval = ... ", IA.sv.profile.DoubleClickInterval or 0.3)
end

function WorldClickHandler:UpdateOverrideBindings()
	-- local CameraBUTTON,TurnBUTTON = 'BUTTON1','BUTTON2'    --'LeftButton','RightButton'
	-- Only the first binding is handled of each command. It cannot be rebound on the UI,so if a user binds more keys to it, definitely knows what he/she is doing.
	local CameraBUTTON,TurnBUTTON = GetBindingKey('CAMERAORSELECTORMOVE'), GetBindingKey('TURNORACTION')
	LibShared.softassert(CameraBUTTON and not CameraBUTTON:match('-'), "CameraBUTTON has modifier in it, AutoRunCombo will not work.")
	LibShared.softassert(  TurnBUTTON and not   TurnBUTTON:match('-'), "TurnBUTTON has modifier in it, accidental rightclick protection will not work.")
	handler:Execute(" CameraBUTTON,TurnBUTTON = ... ", CameraBUTTON,TurnBUTTON)
end


function WorldClickHandler:Enable(enable)
	if  not self.enable == not enable  then  return nil  end
	self.enable = enable

	if enable then  self:InitSecureHandler()
	else  self:DisableHandler()  end
	return true
end


--[[
/dump WCH.RunAttribute, WCH.RunSnippet, WCH.Run, WCH.CallMethod, WCH.ChildUpdate, WCH.SetFrameRef
/dump WorldFrame:HasScript('OnClick'), WorldFrame:HasScript('PreClick'), WorldFrame:HasScript('PostClick'), WorldFrame:HasScript('OnMouseUp'), WorldFrame:HasScript('OnMouseDown')
--]]




--[[
/run ImmersiveAction:OverrideCommandsIn('ActionMode', true)
/run ImmersiveAction:OverrideCommandsIn('AutoRun', true)
/run SetOverrideBinding(ImmersiveAction.UserBindings, false, 'BUTTON1', nil) ; SetOverrideBinding(ImmersiveAction.UserBindings, false, 'BUTTON2', nil)

/dump  ImmersiveAction.UserBindings.keyMap
/run  ClearOverrideBindings(ImmersiveAction.UserBindings) ; ImmersiveAction.UserBindings.keyMap= nil
/run  SetOverrideBinding(ImmersiveAction.UserBindings, false, 'BUTTON1', nil)
/run  SetOverrideBinding(ImmersiveAction.UserBindings, false, 'BUTTON1', 'TURNORACTION')
/run  ImmersiveAction:UpdateUserBindings()

/run  SetBinding('BUTTON2', 'MOVEANDSTEER')
/run  SetOverrideBinding(ImmersiveAction.OverrideBindings, false, 'BUTTON2', 'MOVEANDSTEER')
/run  SetOverrideBinding(ImmersiveAction.OverrideBindings, false, 'BUTTON2', nil)
/run  SetMouselookOverrideBinding('X')

/run  ImmersiveAction:OverrideCommandsIn('ActionMode',true)
/run  ImmersiveAction:OverrideCommandsIn('AutoRun',true)
--]]



