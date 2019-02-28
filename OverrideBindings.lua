local GL, ADDON_NAME, ADDON = _G, ...
local IA = GL.ImmersiveAction or {}  ;  GL.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log

-- Used from LibShared:
local ipairsOrOne,packOrOne,pairsOrNil = LibShared:Import('ipairsOrOne,packOrOne,pairsOrNil,', IA)




------------------------------
-- Declare the command overrides in specific modes
-- OverridesIn[mode][fromCmd] = toCmd
------------------------------

local OverridesIn = { ActionMode = {}, AutoRun = {}, MoveAndSteer = {}, InteractNearest = {}, Mouselook = {}, General = {} }
IA.OverridesIn = OverridesIn

--- INTERACTMOUSEOVER --> TURNORACTION -- Invert Mouselook.
-- InteractMouseover is useless without cursor (in Mouselook mode).
-- Typically pressed if the user wants the mouse to select something so release the cursor with RightButton's command.
-- Only the first binding supported.
OverridesIn.Mouselook.INTERACTMOUSEOVER = 'TURNORACTION'

--- MOVEANDSTEER --> MOVEFORWARD for AutoRun to fix the abrupt stop.
-- MoveAndSteerStop() stops AutoRun, which is very disturbing when turning with MoveAndSteer while in AutoRun mode.
-- Override at all times, losing Mouselook, and patch it back in  :SetCommandState()
OverridesIn.General.MOVEANDSTEER = 'MOVEFORWARD'
-- Override to TurnOrAction in AutoRun mode to avoid this annoyance. This is effective even out of ActionMode.
OverridesIn.AutoRun.MOVEANDSTEER = 'TURNORACTION'         -- Note: override the General override.
-- OverridesIn.AutoRun.TURNORACTION = 'TurnWithoutInteract'    -- This is not priority.
OverridesIn.AutoRun.AUTORUN = 'TurnWithoutInteract'
OverridesIn.MoveAndSteer.TURNORACTION = 'AUTORUN'         -- MoveAndSteer + RightButton -> AutoRun
OverridesIn.ActionMode.TURNORACTION = 'ReleaseCursor'     -- This is the priority.
-- OverridesIn.ActionMode.CAMERAORSELECTORMOVE = 'MOVEFORWARD'    -- This is user setting.
-- Or override with MoveForward in ActionMode, but that's no help out of ActionMode.
-- OverrideBindings.OverridesIn.ActionMode.MOVEANDSTEER = 'MoveForward'

-- TODO: Should only override MouseButton bindings.
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


function UserBindings:SetUserBinding(mode, key, command)
	IA.db.profile['bindingsIn'..mode][key] = value
	self:OverrideOneBinding(mode, key, command)
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
		-- LibShared.softassertf(not oldKey or oldKey==newKey, "UserBindings:OverrideBindings(): command %s already registered, overwriting:  %s  ->  %s", toCmd, oldKey, newKey)
		cmdKeyMap[toCmd] = newKey
		print("UserBindings: SetOverrideBinding(.., "..newKey..", "..tostring(toCmd))
		SetOverrideBinding(self, false, newKey, toCmd)
	end end -- for for
end



function UserBindings:OverrideUserBindings(mode, enable)
	if enable then  self:OverrideBindings(mode, IA.db.profile['bindingsIn'..mode])  end
end


function UserBindings:UpdateUserBindings()
	print("UserBindings:UpdateUserBindings()")
	-- First happens in response to ADDON_LOADED. Later on ProfileChanged()  and  when a binding is changed in Config.
	--[[
	MouselookStop() won't interrupt command keys that are pressed, i.e. received "down" event, but not "up"
	Those commands will not run for the "up" event if their binding is changed, instead
	the new binding will receive the "up" event without a "down" event.
	This results in unexpectedly entering or leaving ImmersiveAction when rebinding a command that changes ImmersiveAction.
	--]]
	local wasMouselooking = IA.IsMouselooking()
	if wasMouselooking then
		-- Log.Anomaly('UserBindings:UpdateUserBindings() while IsMouselooking() could cause stuck keys, not updating bindings.')
		-- return
		Log.Anomaly('UserBindings:UpdateUserBindings() while IsMouselooking() could cause stuck keys, temporarily disabling Mouselook.')
		IA.MouselookStop()
	end

	ClearOverrideBindings(UserBindings)
	self:OverrideUserBindings('General', true)
	self:OverrideUserBindings('ActionMode', IA.commandState.ActionMode)

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


function OverrideBindings:OverrideCommands(overrides, enable, priority)
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
		GL.SetMouselookOverrideBinding(key, nil)
	end
	wipe(self.MouselookOverrides)
end


function OverrideBindings:SetMouselookOverrideBindings(fromCmd, toCmd)
	-- Keys to override when enabled.
	for i,key in ipairsOrOne(self.cmdKeys[fromCmd]) do
		if LibShared.softassert(not self.MouselookOverrides[key]) then
			LibShared.softassertf(fromCmd~='TURNORACTION' and fromCmd~='TARGETSCANENEMY', "SetMouselookOverrideBindings():  overriding bindings of %q to %q will cause stucking in Mouselook mode.", fromCmd, toCmd)
			self.MouselookOverrides[key] = toCmd
			GL.SetMouselookOverrideBinding(key, toCmd)
		end
	end
end




------------------------------
-- Enable the overrides in specific modes.
------------------------------

function OverrideBindings:OverrideCommandsIn(mode, enable)
	self:OverrideCommands(OverridesIn[mode], enable and IA.commandState[mode])
end


function OverrideBindings:UpdateOverrides(enable)
	if InCombatLockdown() then
		Log.State("ImmersiveAction:UpdateOverrides() ignored:  Can't update bindings when InCombatLockdown()")
	else
		print("ImmersiveAction:UpdateOverrides("..IA.colorBoolStr(enable, true)..")")
		if enable==nil then  enable = true  end
		if enable then  self:OverrideCommandsIn('General'   , enable)  end
		self:OverrideCommandsIn('AutoRun'   , enable)
		self:OverrideCommandsIn('MoveAndSteer', enable)
		self:OverrideCommandsIn('ActionMode', enable)
		IA.UserBindings:UpdateUserBindings()
	end
end


-- Disable OverrideBindings before combat.
function OverrideBindings:PLAYER_REGEN_DISABLED(event)
	-- self:OverrideCommandsIn('AutoRun'      , false)
	-- self:OverrideCommandsIn('ActionMode'   , false)
	self:UpdateOverrides(false)
end

-- Enable OverrideBindings after combat, depending on IA.commandState[mode].
function OverrideBindings:PLAYER_REGEN_ENABLED(event)
	-- self:OverrideCommandsIn('AutoRun')
	-- self:OverrideCommandsIn('ActionMode')
	self:UpdateOverrides(true)
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
	IA.commandState.General = enable
	self:OverrideCommandsIn('General', enable)
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
		OverrideBindings:CaptureBindings(mode, overrides)
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

local MapButtonToKey = LibShared.MapButtonToKey
-- for i=4,8 do  MapButtonToKey['Button'..i] = 'BUTTON'..i  end
-- for i=4,16 do  MapButtonToKey['Button'..i] = 'BUTTON'..i  end
-- for i=4,31 do  MapButtonToKey['Button'..i] = 'BUTTON'..i  end




--[[
/run ImmersiveAction.FixB2 = false
/run ImmersiveAction.FixB2 = true
/run WorldFrame:HookScript('OnMouseUp', ImmersiveAction.WorldClickHandler.FixAccidentalRightClick)
/run WorldFrame:HookScript('OnMouseUp', error)
/run UIParent:HookScript('OnMouseUp', ImmersiveAction.WorldClickHandler.FixAccidentalRightClick)
/run WorldFrame:SetScript('OnMouseUp', ImmersiveAction.WorldClickHandler.FixAccidentalRightClick)
/run UIParent:SetScript('OnMouseUp', ImmersiveAction.WorldClickHandler.FixAccidentalRightClick)
/dump ImmersiveAction.WorldClickHandler.FixAccidentalRightClick
/dump UIParent:GetScript('OnMouseUp') == ImmersiveAction.WorldClickHandler.FixAccidentalRightClick
/dump GetModifiedClick('Interact')
/dump IsModifiedClick('Interact')
--]]
-------------------------------
local WorldClickHandler = CreateFrame('Frame', nil, nil, 'SecureHandlerMouseUpDownTemplate')
IA.WorldClickHandler = WorldClickHandler
-- Export to _G.WCH for DEVMODE.
if GL.DEVMODE then  GL.WCH = GL.WCH or WCH  end

-- Last GetTime() when the TurnButton (RightButton by default) was clicked.
WorldClickHandler.LastTurnClick = 0


-- Methods before being hooked.
WorldClickHandler.originalM = { [WorldFrame] = {}, [UIParent] = {} }
-- Methods after being hooked. These are secure wrapper closures generated
-- by hooksecurefunc(frame, methodName, postHook) which calls, in order:  originalM[frame][methodName]  and  postHook.
WorldClickHandler.hookedM   = { [WorldFrame] = {}, [UIParent] = {} }

-- Scripts before being hooked.
WorldClickHandler.originalS = { [WorldFrame] = {}, [UIParent] = {} }
-- Scripts after being hooked. These are secure wrapper closures generated
-- by frame.HookScript(scriptName, postHook) which calls, in order:  originalS[frame][scriptName]  and  postHook.
WorldClickHandler.hookedS   = { [WorldFrame] = {}, [UIParent] = {} }


function WorldClickHandler.SetScript(frame, scriptName, callback)
	LibShared.softassert(false, frame:GetName().."."..scriptName.."  SetScript-ed to next error:")
	-- Without frame argument it is bound to crash on nil, if it's not a dummy.
	GL.xpcall(callback)
end

function WorldClickHandler.HookScript(frame, scriptName, postFunc)
	LibShared.softassert(false, frame:GetName().."."..scriptName.."  HookScript-ed to next error:")
	-- Without frame argument it is bound to crash on nil, if it's not a dummy.
	GL.xpcall(postFunc)
end


function WorldClickHandler.UIOnMouseDown(frame, button)
	print("UIParent", IA.coloredKey(button, true))
end

function WorldClickHandler.UIOnMouseUp(frame, button)
	print("UIParent", IA.coloredKey(button, false))
end


function WorldClickHandler.OnMouseDown(frame, button)
	local self = WorldClickHandler
	-- If the OnMouseUp hook runs before TurnOrActionStop(),
	-- then similarly OnMouseDown runs before TurnOrActionStart(), right?  (before hiding the mouseover)
	self.wasMouseover = UnitExists('mouseover')
	print()
	self.counter = (self.counter or 0) + 1
	print("        ", self.counter, frame:GetName(), IA.coloredKey(button, true))

	if self.prevClickToMove then  SetCVar("AutoInteract", self.prevClickToMove) ; self.prevClickToMove = nil  end
end


function WorldClickHandler.OnMouseUp(frame, button)
	local self = WorldClickHandler
	print("        ", self.counter, frame:GetName(), IA.coloredKey(button, false) )
	local key = MapButtonToKey[button]
	if  key == self.BUTTONs.TURNORACTION  then
	-- if button == 'RightButton' then
		WorldClickHandler.FixRightClick(frame, button)
	end
end


function WorldClickHandler.FixRightClick(frame, button)
	if IA.commandState.ActionMode then
		-- In ActionMode pressing TurnOrAction (RightButton) will show the cursor, and when released
		-- it will Interact with anything under the cursor. This needs some trickery, perhaps:
		-- Enable Mouselook early, _before_ the button release is processed, so it counts as a RightButton released after Mouselooking,
		-- that translates to an Interact action. Will work until bliz changes its handling of bindings.
		-- Thought:  rightclick interacts if and only if its pressed for a short time, some ClickInterval.
		-- What starts the timer? MouselookStart? Then this will work with 0 pressed time.
		-- Or TurnOrActionStart? That happened long ago, the user was targeting with the cursor, certainly longer than say 0.3 sec.
		-- In that case targeting + doubleclick will do the 2nd click within the time limit. Quirky.
		IA.MouselookStart()
	else
		-- CursorMode
		WorldClickHandler:FixAccidentalRightClick(frame, button)
	end
end


WorldClickHandler.PreventAllSingleClicks = false
WorldClickHandler.RunToDoubleClickGround = true
WorldClickHandler.RunToDoubleClickMouseover = true

function WorldClickHandler:FixAccidentalRightClick(frame, button)
	if IA.FixB2 == false then  return  end
	if not IsMouselooking() then  return  end
	if IsModifiedClick('Interact') then  return  end

	local DoubleClickInterval = IA.db.profile.DoubleClickInterval or 0.3
	local now, last = GetTime(), self.LastTurnClick
	self.LastTurnClick = now

	-- local mouseover = UnitExists('mouseover')  --  Always nil: mouseover is hidden when IsMouselooking()

	if self.prevClickToMove then  SetCVar("AutoInteract", self.prevClickToMove) ; self.prevClickToMove = nil  end

	if  now-last > DoubleClickInterval then
		-- NOT DoubleClick
		if self.wasMouseover or self.PreventAllSingleClicks then
			print("IA.FixB2: MouselookStop()")
			IA.MouselookStop()    -- Trick TurnOrActionStop() into believing it was not pressed.
		end
  elseif  self.RunToDoubleClickMouseover  and  self.wasMouseover
	or  self.RunToDoubleClickGround  and  not self.wasMouseover
  then  --  and not InCombatLockdown() then
		print("IA.FixB2: RunToDoubleClick")
		local prevClickToMove= GetCVar('AutoInteract')    --  Adequately named cvar.
		if  prevClickToMove ~= '1'  then  SetCVar('AutoInteract', '1') ; self.prevClickToMove = prevClickToMove  end
	else
		print("IA.FixB2: Interact")
	end
end




-------------------------------
-- Experiment: SecureHandler hooking WorldFrame to capture mouse button commands.
-- Result:  WorldFrame has no OnClick handler (not a Button), and SecureHandlerClickTemplate don't support OnMouseDown/OnMouseUp handlers.
-- Trying SecureHandlerMouseUpDownTemplate.
-------------------------------

---------- Ctrl+LeftClick UP:  what is Ctrl-B1-UP stickycamera??
---------- CameraOrSelectOrMoveStop(IsModifiedClick("STICKYCAMERA"));


-- Secure wrapper function WorldFrame_OnMouseDown_PreSnippet(self, button)
-- If CameraButton (LeftButton) is pressed then rebinds TurnBUTTON (BUTTON2) to AUTORUN.
-- In the secure environment:  owner == WorldClickHandler, self == WorldFrame  and  control == owner, i guess, but no code or documentation confirms.
local WorldFrame_OnMouseDown_PreSnippet = [===[
	print(" WorldFrame_OnMouseDown_PreSnippet("..button..") ")
	local key = MapButtonToKey[button]
	Pressed[#Pressed+1] = key
	Pressed[key] = #Pressed

	if Rebound[key] then  return  end
	if  key == BUTTONs.TURNORACTION  and  Pressed[BUTTONs.CAMERAORSELECTORMOVE]  then
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
-- v0.2:  Rebinds TurnBUTTON (BUTTON2) to TurnWithoutInteract, avoiding the Interact action.
-- This happens before the MouseDown event is mapped to the standard TurnOrAction command. Post-release the hijack is disabled.
-- v0.3:  Simply calls MouselookStop() - an independent aspect in concept, but it tracks the pressed state of TurnOrAction.
-- Turning it off makes wow think the button was not pressed, and the release event is just a phantom signal.
-- Curious thing is the HookScript runs after the builtin OnMouseUp handler, so what comes even later that actually handles the key release?
-- v4:  Test if simply consuming the MouseDown event with `return false` is sufficient to fix this issue.
-- MouselookStop() is still necessary, otherwise it gets stuck. UpdateMouselook() can do it, but the trigger of
-- TurnOrActionStop() is also eliminated, confusing the StateHandler ExpectedMouselook(). Can be replace with  IA:CommandHook('TurnOrAction', false, 'TurnOrActionStop')
-- Verdict:  MouselookStop() is more compatible with hooking TurnOrActionStop().
-- This implementation uses the MouselookStop() method. Will work, until bliz fixes the design flaw of TurnOrActionStop(), present since 2004.
--
-- Secure wrapper function WorldFrame_OnMouseUp_PreSnippet(self, button)
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

	if  key == BUTTONs.TURNORACTION  and  not Rebound[key]  and  not IsModifiedClick('Interact')  then
		local now, last = owner:GetTime(), LastTurnClick
		LastTurnClick = now
		if DoubleClickInterval < now-last then
			-- Rebound[key] = 'TurnWithoutInteract'
			-- owner:SetBinding(false, key, 'TurnWithoutInteract')
			owner:CallMethod('MouselookStop')    -- Hack TurnOrActionStop() into believing it was not pressed.
			-- return false
		end
	end
	return nil, true  -- Don't change button, do invoke post-handler.
]===]
-- LastTurnClick is updated for doubleclicks too, so as long as the user lands clicks in 0.3 sec, all clicks will Interact.
-- Spamming clicks still works, but a single click is prevented from an accidental pull or targeting.


-- Secure wrapper function WorldFrame_OnMouseUp_PostSnippet(self, message, button)
local WorldFrame_OnMouseUp_PostSnippet = [===[
	print(" WorldFrame_OnMouseUp_PostSnippet("..button..") ")

	local key = MapButtonToKey[button]
	if Rebound[key] then
		Rebound[key] = nil
		owner:ClearBinding(key)
	end
]===]



-- Secure wrapper function UIParent_OnMouseWheel_PreSnippet(self, offset)
local UIParent_OnMouseWheel_PreSnippet = [===[
	-- print(" UIParent_OnMouseWheel_PreSnippet("..self:GetName(self)..", offset="..tostring(offset)..") ")
	return nil, true  -- Allow original handler, then invoke post-handler.
]===]



-- Secure wrapper function UIParent_OnMouseWheel_PostSnippet(self, message, offset)
local UIParent_OnMouseWheel_PostSnippet = [===[
	print(" UIParent_OnMouseWheel_PostSnippet("..self:GetName()..", offset="..tostring(offset)..") ")
]===]



WorldClickHandler.InitSnippet = [===[
	-- I will definitely forget to initialize this:
	LastTurnClick, DoubleClickInterval = 0, 0.3
	Pressed = newtable()
	Rebound = newtable()
	-- BUTTONs = newtable()

	MapButtonToKey = newtable()
	MapButtonToKey.LeftButton = BUTTON1
	MapButtonToKey.RightButton = BUTTON2
	MapButtonToKey.MiddleButton = BUTTON3
	for i=4,31 do  MapButtonToKey['Button'..i] = 'BUTTON'..i  end
]===]


local function WrapScript(frame, scriptName, handler, pre, post)
	local OnMouseWheel = frame:GetScript('OnMouseWheel')
	frame:SetScript('OnMouseWheel', frame:GetScript(scriptName))
	SecureHandlerWrapScript(frame, 'OnMouseWheel', handler, pre, post)
	frame:SetScript(scriptName, frame:GetScript('OnMouseWheel'))
	frame:SetScript('OnMouseWheel', OnMouseWheel)
end



local function UnhookM(self, target, methodName)
	if self.hookedM[target][methodName] == target[methodName] then
		target[methodName] = self.originalM[target][methodName]
		self.hookedM[target][methodName] = nil
		return true
	end
	return false
end

local function UnhookS(self, target, scriptName)
	if self.hookedS[target][scriptName] == target:GetScript(scriptName) then
		target:SetScript(scriptName, self.originalS[target][scriptName])
		self.hookedS[target][scriptName] = nil
		return true
	end
	return false
end


local function HookM(self, target, methodName, postFunc)
	if not postFunc then  return UnhookM(self, target, methodName)  end
	if self.hookedM[target][methodName] then  return false  end
	self.originalM[target][methodName] = target[methodName]
	GL.hooksecurefunc(target, methodName, postFunc)
	self.hookedM[target][methodName] = target[methodName]
	return true
end

local function HookS(self, target, scriptName, postFunc)
	if not postFunc then  return UnhookS(self, target, scriptName)  end
	if self.hookedS[target][scriptName] then  return false  end
	self.originalS[target][scriptName] = target:GetScript(scriptName)
	target:HookScript(scriptName, postFunc)
	self.hookedS[target][scriptName] = target:GetScript(scriptName)
	return true
end


function WorldClickHandler:InitSecureHandler()
	local handler = self    -- For clarity.
	-- Init "global" variables in secure environment.
	-- handler:SetAttribute('_set', " local name,value=... ; _G[name] = value ")

	-- handler.MouselookStop = IA.MouselookStop
	handler:Execute(WorldClickHandler.InitSnippet)
	handler.Env = GL.GetManagedEnvironment(handler)

	-- handler:WrapScript(WorldFrame, 'OnMouseDown', prePressBody, nil)
	-- handler:WrapScript(WorldFrame, 'OnMouseUp'  , preReleaseBody, postReleaseBody)
	-- Same with less calls:
	-- SecureHandlerWrapScript(WorldFrame, 'OnMouseDown', handler, WorldFrame_OnMouseDown_PreSnippet, nil)
	-- SecureHandlerWrapScript(WorldFrame, 'OnMouseUp'  , handler, WorldFrame_OnMouseUp_PreSnippet, WorldFrame_OnMouseUp_PostSnippet)

	-- WrapScript(WorldFrame, 'OnMouseDown', handler, WorldFrame_OnMouseDown_PreSnippet, nil)
	-- WrapScript(WorldFrame, 'OnMouseUp', handler, WorldFrame_OnMouseUp_PreSnippet, WorldFrame_OnMouseUp_PostSnippet)

	-- SecureHandlerWrapScript(WorldFrame, 'OnClick', handler, WorldFrame_OnClick_PreSnippet, WorldFrame_OnClick_PostSnippet)
	-- WorldFrame has no OnClick script... splendid.
  -- OnMouseDown/OnMouseUp cannot be wrapped, therefore altered by a third-party.
	-- Only insecure, post-handler is possible with HookScript('OnMouseDown'). This cannot alter bindings in combat.
	if not self.hookedS[WorldFrame].OnMouseUp then
		HookS(self, WorldFrame, 'OnMouseWheel', self.OnMouseWheel)
		HookS(self, UIParent  , 'OnMouseWheel', self.OnMouseWheel)

		HookS(self, WorldFrame, 'OnMouseDown', self.OnMouseDown)
		HookS(self, WorldFrame, 'OnMouseUp'  , self.OnMouseUp  )
		HookS(self, UIParent  , 'OnMouseDown', self.UIOnMouseDown)
		HookS(self, UIParent  , 'OnMouseUp'  , self.UIOnMouseUp  )

		HookM(self, WorldFrame, 'SetScript'  , self.SetScript  )
		HookM(self, WorldFrame, 'SetScript'  , self.SetScript  )
		HookM(self, UIParent  , 'HookScript' , self.HookScript )
		HookM(self, UIParent  , 'HookScript' , self.HookScript )
	end

	-- SecureHandlerWrapScript(WorldFrame, 'OnMouseWheel', handler, UIParent_OnMouseWheel_PreSnippet, UIParent_OnMouseWheel_PostSnippet)
	-- SecureHandlerWrapScript(UIParent, 'OnMouseWheel', handler, UIParent_OnMouseWheel_PreSnippet, UIParent_OnMouseWheel_PostSnippet)
	
	handler:UpdateDoubleClickInterval()
	handler:UpdateOverrideBindings()
end


function WorldClickHandler:DisableHandler()
	-- self:UnwrapScript(WorldFrame, 'OnMouseDown')
	-- self:UnwrapScript(WorldFrame, 'OnMouseUp')
	self:UnwrapScript(WorldFrame, 'OnMouseWheel')
	self:UnwrapScript(UIParent  , 'OnMouseWheel')

	HookS(self, WorldFrame, 'OnMouseWheel', false)
	HookS(self, UIParent  , 'OnMouseWheel', false)

	HookS(self, WorldFrame, 'OnMouseDown', false)
	HookS(self, WorldFrame, 'OnMouseUp'  , false)
	HookS(self, UIParent  , 'OnMouseDown', false)
	HookS(self, UIParent  , 'OnMouseUp'  , false)

	HookM(self, WorldFrame, 'SetScript'  , false)
	HookM(self, WorldFrame, 'SetScript'  , false)
	HookM(self, UIParent  , 'HookScript' , false)
	HookM(self, UIParent  , 'HookScript' , false)
end


function WorldClickHandler:UpdateDoubleClickInterval()
	self:Execute(" DoubleClickInterval = "..(IA.db.profile.DoubleClickInterval or 0.3) )
end


function WorldClickHandler:UpdateOverrideBindings()
	-- local CameraBUTTON,TurnBUTTON = 'BUTTON1','BUTTON2'    --'LeftButton','RightButton'
	-- Only the first binding is handled of each command. It cannot be rebound on the UI,so if a user binds more keys to it, definitely knows what he/she is doing.
	local BUTTONs = {}
	WorldClickHandler.BUTTONs = BUTTONs
	BUTTONs.CAMERAORSELECTORMOVE = GetBindingKey('CAMERAORSELECTORMOVE')
	BUTTONs.TURNORACTION         = GetBindingKey('TURNORACTION')
	local Camera,Turn = BUTTONs.CAMERAORSELECTORMOVE, BUTTONs.TURNORACTION
	LibShared.softassert(Camera and not Camera:match('-'), "CAMERAORSELECTORMOVE binding has modifier in it, AutoRunCombo will not work.")
	LibShared.softassert(  Turn and not   Turn:match('-'), "TURNORACTION has modifier in it, accidental rightclick protection will not work.")
	self:Execute(" CameraBUTTON,TurnBUTTON = '"..Camera.."','"..Turn.."' ")
	self:Execute(" BUTTONs = newtable() ")
	self:Execute(" BUTTONs.CAMERAORSELECTORMOVE = '"..Camera.."' ")
	self:Execute(" BUTTONs.TURNORACTION = '"        ..Turn.."' ")
end


--[[
function WorldClickHandler:UpdateOverrideBindings2()
	-- local CameraBUTTON,TurnBUTTON = 'BUTTON1','BUTTON2'    --'LeftButton','RightButton'
	-- Only the first binding is handled of each command. It cannot be rebound on the UI,so if a user binds more keys to it, definitely knows what he/she is doing.
	local CameraBUTTON,TurnBUTTON = GetBindingKey('CAMERAORSELECTORMOVE'), GetBindingKey('TURNORACTION')
	LibShared.softassert(CameraBUTTON and not CameraBUTTON:match('-'), "CameraBUTTON has modifier in it, AutoRunCombo will not work.")
	LibShared.softassert(  TurnBUTTON and not   TurnBUTTON:match('-'), "TurnBUTTON has modifier in it, accidental rightclick protection will not work.")
	self:Execute(" CameraBUTTON,TurnBUTTON = '"..CameraBUTTON.."','"..TurnBUTTON.."' ")
end
--]]


function WorldClickHandler:Enable(enable)
	if  not self.enable == not enable  then  return nil  end
	self.enable = enable
	return true
end


--[[
/dump WCH.RunAttribute, WCH.RunSnippet, WCH.Run, WCH.CallMethod, WCH.ChildUpdate, WCH.SetFrameRef
/dump WorldFrame:HasScript('OnClick'), WorldFrame:HasScript('PreClick'), WorldFrame:HasScript('PostClick'), WorldFrame:HasScript('OnMouseUp'), WorldFrame:HasScript('OnMouseDown')
--]]




--[[
/run ImmersiveAction.OverrideBindings:OverrideCommandsIn('ActionMode', true)
/run ImmersiveAction.OverrideBindings:OverrideCommandsIn('AutoRun', true)
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

/run  ImmersiveAction.OverrideBindings:OverrideCommandsIn('ActionMode',true)
/run  ImmersiveAction.OverrideBindings:OverrideCommandsIn('AutoRun',true)
--]]



