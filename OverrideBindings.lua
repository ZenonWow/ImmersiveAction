local G, ADDON_NAME, ADDON = _G, ...
local IA = G.ImmersiveAction or {}  ;  G.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log

-- Used from LibShared:
local ipairsOrOne,packOrOne,pairsOrNil = LibShared:Import('ipairsOrOne,packOrOne,pairsOrNil', IA)




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
-- OverridesIn.MoveAndSteer.TURNORACTION = 'AUTORUN'         -- MoveAndSteer + RightButton -> AutoRun not working. AUTORUN does nothing on B1,B2
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


function UserBindings:SetUserBinding(mode, key, toCmd)
	IA.db.profile['bindingsIn'..mode][key] = toCmd
	self:OverrideOneBinding(mode, key, toCmd)
end


function UserBindings:OverrideOneBinding(mode, key, toCmd)
	if key=='' then  key = nil  end

	local cmdKeyMap = self.cmdKeyMaps[mode]
	if not cmdKeyMap then  cmdKeyMap = {} ; self.cmdKeyMaps[mode] = cmdKeyMap  end

	local oldKey = cmdKeyMap[toCmd]
	if oldKey then  SetOverrideBinding(self, false, oldKey, nil)  end
	cmdKeyMap[toCmd] = key
	SetOverrideBinding(self, false, key, toCmd)
end



function UserBindings:OverrideBindings(mode, keyBindings)
	if not keyBindings then  return  end

	local cmdKeyMap = self.cmdKeyMaps[mode]
	if not cmdKeyMap then  cmdKeyMap = {} ; self.cmdKeyMaps[mode] = cmdKeyMap  end

	-- Set new overrides
	for key,toCmd in pairs(keyBindings) do  if toCmd~='' then
		if key=='' then  key = nil  end
		local oldKey = cmdKeyMap[toCmd]
		-- LibShared.softassertf(not oldKey or oldKey==key, "UserBindings:OverrideBindings(): command %s already registered, overwriting:  %s  ->  %s", toCmd, oldKey, key)
		cmdKeyMap[toCmd] = key
		-- print("UserBindings:, key, "   ==>   ", toCmd)
		SetOverrideBinding(self, false, key, toCmd)
	end end -- for for
end



function UserBindings:OverrideUserBindings(mode, enable)
	if enable then  self:OverrideBindings(mode, IA.db.profile['bindingsIn'..mode])  end
end


function UserBindings:UpdateUserBindings()
	print("UserBindings:UpdateUserBindings()")
	-- First happens in response to ADDON_LOADED. Later on ProfileChanged()  and  when a binding is changed in Config.
	--[[
	MouselookStop() won't release command keys that are pressed, i.e. received "down" event, but not "up".
	Those commands will not run for the "up" event if their binding is changed, instead
	the new binding will receive the "up" event without a "down" event.
	This results in unexpectedly entering or leaving MouselookMode when rebinding a command that changes Mouselook.
	--]]
	local wasMouselooking = IA.IsMouselooking()
	if wasMouselooking then
		-- Log.Anomaly('UserBindings:UpdateUserBindings() while IsMouselooking() could cause stuck keys, temporarily disabling Mouselook.')
		IA.MouselookStop()
	end

	ClearOverrideBindings(UserBindings)
	self:OverrideUserBindings('General', true)
	self:OverrideUserBindings('ActionMode', IA.activeCommands.ActionMode)

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
		G.SetMouselookOverrideBinding(key, nil)
	end
	wipe(self.MouselookOverrides)
end


function OverrideBindings:SetMouselookOverrideBindings(fromCmd, toCmd)
	-- Keys to override when enabled.
	for i,key in ipairsOrOne(self.cmdKeys[fromCmd]) do
		if LibShared.softassert(not self.MouselookOverrides[key]) then
			LibShared.softassertf(fromCmd~='TURNORACTION' and fromCmd~='TARGETSCANENEMY', "SetMouselookOverrideBindings():  overriding bindings of %q to %q will cause stucking in Mouselook mode.", fromCmd, toCmd)
			self.MouselookOverrides[key] = toCmd
			G.SetMouselookOverrideBinding(key, toCmd)
		end
	end
end




------------------------------
-- Enable the overrides in specific modes.
------------------------------

function OverrideBindings:OverrideCommandsIn(mode, enable)
	self:OverrideCommands(OverridesIn[mode], enable and IA.activeCommands[mode])
end


function OverrideBindings:UpdateOverrides(enable)
	if InCombatLockdown() then
		Log.State("OverrideBindings:UpdateOverrides() ignored:  Can't update bindings when InCombatLockdown()")
	else
		print("OverrideBindings:UpdateOverrides("..IA.colorBoolStr(enable, true)..")")
		if enable==nil then  enable = true  end
		IA.UserBindings:UpdateUserBindings()
		if enable then  self:OverrideCommandsIn('General'   , enable)  end
		self:OverrideCommandsIn('AutoRun'   , enable)
		self:OverrideCommandsIn('MoveAndSteer', enable)
		self:OverrideCommandsIn('ActionMode', enable)
	end
end


-- Disable OverrideBindings before combat.
function OverrideBindings:PLAYER_REGEN_DISABLED(event)
	-- self:OverrideCommandsIn('AutoRun'      , false)
	-- self:OverrideCommandsIn('ActionMode'   , false)
	self:UpdateOverrides(false)
end

-- Enable OverrideBindings after combat, depending on IA.activeCommands[mode].
function OverrideBindings:PLAYER_REGEN_ENABLED(event)
	-- self:OverrideCommandsIn('AutoRun')
	-- self:OverrideCommandsIn('ActionMode')
	self:UpdateOverrides(true)
end

function OverrideBindings:Enable(enable)
	if  not self.enable == not enable  then  return nil  end
	self.enable = enable

	-- IA.activeCommands.OverrideBindings = enable
	if enable then
		self:RegisterEvent('PLAYER_REGEN_DISABLED')
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
		self:PLAYER_REGEN_ENABLED('Enable(true)')
	else
		self:UnregisterEvent('PLAYER_REGEN_DISABLED')
		self:UnregisterEvent('PLAYER_REGEN_ENABLED')
		self:PLAYER_REGEN_DISABLED('Enable(false)')
	end
	IA.activeCommands.General = enable
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







local MapButtonToKey = LibShared.Require.MapButtonToKey




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
if G.DEVMODE then  G.WCH = G.WCH or WCH  end

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


local function UnhookM(self, target, methodName)
	if self.hookedM[target][methodName] == target[methodName] then
		target[methodName] = self.originalM[target][methodName]
		self.hookedM[target][methodName] = nil
		return true
	end
	return false
end

local function HookM(self, target, methodName, postFunc)
	if not postFunc then  return UnhookM(self, target, methodName)  end
	if self.hookedM[target][methodName] then  return false  end
	self.originalM[target][methodName] = target[methodName]
	G.hooksecurefunc(target, methodName, postFunc)
	self.hookedM[target][methodName] = target[methodName]
	return true
end


local function UnhookS(self, target, scriptName)
	if self.hookedS[target][scriptName] == target:GetScript(scriptName) then
		target:SetScript(scriptName, self.originalS[target][scriptName])
		self.hookedS[target][scriptName] = nil
		return true
	end
	return false
end

local function HookS(self, target, scriptName, postFunc)
	-- print('HookS', target, scriptName, not not postFunc)
	if not postFunc then  return UnhookS(self, target, scriptName)  end
	if self.hookedS[target][scriptName] then  return false  end
	self.originalS[target][scriptName] = target:GetScript(scriptName)
	target:HookScript(scriptName, postFunc)
	self.hookedS[target][scriptName] = target:GetScript(scriptName)
	return true
end


local function WrapScript(frame, scriptName, handler, pre, post)
	local OnMouseWheel = frame:GetScript('OnMouseWheel')
	frame:SetScript('OnMouseWheel', frame:GetScript(scriptName))
	SecureHandlerWrapScript(frame, 'OnMouseWheel', handler, pre, post)
	frame:SetScript(scriptName, frame:GetScript('OnMouseWheel'))
	frame:SetScript('OnMouseWheel', OnMouseWheel)
end




function WorldClickHandler.SetScript(frame, scriptName, callback)
	LibShared.softassert(false, frame:GetName().."."..scriptName.."  SetScript-ed to next error:")
	-- Without frame argument it is bound to crash on nil, if it's not a dummy.
	G.xpcall(callback)
end

function WorldClickHandler.HookScript(frame, scriptName, postFunc)
	LibShared.softassert(false, frame:GetName().."."..scriptName.."  HookScript-ed to next error:")
	-- Without frame argument it is bound to crash on nil, if it's not a dummy.
	G.xpcall(postFunc)
end




function WorldClickHandler.OnMouseWheel(frame, direction)
	local self = WorldClickHandler
	print(frame, IA.coloredKey('MouseWheel', direction < 0))
end

function WorldClickHandler.UIOnMouseDown(frame, button)
	local self = WorldClickHandler
	print("UIParent", IA.coloredKey(button, true))
end

function WorldClickHandler.UIOnMouseUp(frame, button)
	local self = WorldClickHandler
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
	
	local key = MapButtonToKey[button]
	-- Test AUTORUN override.
	-- if key == 'BUTTON1' then  SetOverrideBinding(self, true, 'BUTTON4', 'AUTORUN')  end

	-- Cast the spell on LeftButton even if ActionMode was turned on after starting spell targeting.
	if key == self.BUTTONs.CAMERAORSELECTORMOVE and G.SpellIsTargeting() and IA.IsMouselooking() then
		IA.MouselookStop()
		IA.lastMouselook = false
	end
end


function WorldClickHandler.OnMouseUp(frame, button)
	local self = WorldClickHandler
	print("        ", self.counter, frame:GetName(), IA.coloredKey(button, false) )
	local key = MapButtonToKey[button]
	if  key == self.BUTTONs.TURNORACTION  then
	-- if button == 'RightButton' then
		WorldClickHandler.FixRightClick(frame, button)
	end
	-- if key == 'BUTTON1' then  SetOverrideBinding(self, true, 'BUTTON4', nil)  end
end


function WorldClickHandler.FixRightClick(frame, button)
	if IA.activeCommands.ActionMode then
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
-- WorldClickHandler.RunToDoubleClickGround = true
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
		local prevClickToMove = GetCVar('AutoInteract')    --  Adequately named cvar.
		if  prevClickToMove ~= '1'  then  SetCVar('AutoInteract', '1') ; self.prevClickToMove = prevClickToMove  end
	else
		print("IA.FixB2: Interact")
	end
end




function WorldClickHandler:InitInsecureHooks()
  -- OnMouseDown/OnMouseUp cannot be wrapped, therefore altered by a third-party.
	-- Only insecure, post-handler is possible with HookScript('OnMouseDown'). This cannot alter bindings in combat.
	if self.hookedS[WorldFrame].OnMouseUp then  return  end
	do
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
end


function WorldClickHandler:DisableInsecureHooks()
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


function WorldClickHandler:UpdateOverrideBindings()
	-- local CameraBUTTON,TurnBUTTON = 'BUTTON1','BUTTON2'    --'LeftButton','RightButton'
	-- Only the first binding is handled of each command. It cannot be rebound on the UI,so if a user binds more keys to it, definitely knows what he/she is doing.
	local BUTTONs = {}
	WorldClickHandler.BUTTONs = BUTTONs
	BUTTONs.CAMERAORSELECTORMOVE = GetBindingKey('CAMERAORSELECTORMOVE')
	BUTTONs.TURNORACTION         = GetBindingKey('TURNORACTION')
	--[[
	local Camera,Turn = BUTTONs.CAMERAORSELECTORMOVE, BUTTONs.TURNORACTION
	LibShared.softassert(Camera and not Camera:match('-'), "CAMERAORSELECTORMOVE binding has modifier in it, AutoRunCombo will not work.")
	LibShared.softassert(  Turn and not   Turn:match('-'), "TURNORACTION has modifier in it, accidental rightclick protection will not work.")
	self:Execute(" CameraBUTTON,TurnBUTTON = '"..(Camera or '').."','"..(Turn or '').."' ")
	self:Execute(" BUTTONs = newtable() ")
	self:Execute(" BUTTONs.CAMERAORSELECTORMOVE = '"..Camera.."' ")
	self:Execute(" BUTTONs.TURNORACTION = '"        ..Turn.."' ")
	--]]
end


function WorldClickHandler:Enable(enable)
	if  not self.enable == not enable  then  return nil  end
	self.enable = enable
	if enable
	then  self:InitInsecureHooks()
	else  self:DisableInsecureHooks()
	end
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
/run  ClearOverrideBindings(ImmersiveAction.UserBindings) ; ImmersiveAction.UserBindings.keyMap = nil
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



