-- Methods for event handling, activeCommands update of IA, Mouselook, SmartTargeting
local G, ADDON_NAME, ADDON = _G, ...
local IA = G.ImmersiveAction or {}  ;  G.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log
local colorBoolStr = IA.colorBoolStr
local colors = IA.colors

local SpellIsTargeting,GetCursorInfo,GetUnitSpeed = SpellIsTargeting,GetCursorInfo,GetUnitSpeed

--[[ Analyzing key press state:
-- commands can get stuck in pressed state if the binding is changed and the "up" event goes to a different command
/dump ImmersiveAction.db.profile.enabledOnLogin
/dump ImmersiveAction.activeCommands, ImmersiveAction.commandGroups
/run ImmersiveAction:ResetState()
-- Cause of ImmersiveAction:
/dump ImmersiveAction.db.profile.enableWithMoveKeys, ImmersiveAction.db.profile.enableAfterTurning, ImmersiveAction.db.profile.enableAfterMoveAndSteer
/dump ImmersiveAction.db.profile.disableWithLookAround
/dump ImmersiveAction:ExpectedMouselook()
/dump ImmersiveAction.WindowsOnScreen
/dump ImmersiveAction.activeCommands.WindowOnScreen
-- Overridden bindings:

/dump ImmersiveAction.MouselookOverrideBindings = {}
/dump ImmersiveAction.MoveAndSteerKeys = {}

-- Settings:
/dump ImmersiveAction.db.profile
/dump ImmersiveActionDB
-- Explicit:
/run ImmersiveAction:ResetState()
/run MouselookStart()
/run MouselookStop()
/dump 'Me:'..(UnitIsPVP('player') and 'PvP' or 'non-pvp'), UnitName('target')..':'..(UnitIsPVP('target') and 'PvP' or 'non-pvp')
--]]


------------------------------
--- IA.activeCommands is the key/binding/command pressed state map (action->pressed).
-- This is the input to IA:ExpectedMouselook().
-- IA:ProcessCommand() keeps this updated with UI actions/events.
--
IA.activeCommands = {}

-- commandGroups:  `nil` is 'not pressed'
IA.commandGroups = {
	Turn        = {},
	Pitch       = {},
	MoveKeys    = {},
	MouseTurn   = {},
	MouseCursor = {},
}

IA.commandGrouping = {
	TurnLeft			= 'Turn',
	TurnRight			= 'Turn',
	PitchUp				= 'Pitch',
	PitchDown			= 'Pitch',

	-- CameraOrSelectOrMove = false,
	CameraOrSelectOrMove = 'MouseCursor',
	TurnOrAction	= 'MouseTurn',
	-- TurnOrAction	= false,            -- Custom: sets Mouselook to inverse of lastMouselook.
	TurnWithoutInteract = 'MouseTurn',
	ReleaseCursor       = 'MouseCursor',

	MoveAndSteer  = 'MouseTurn',
	-- TargetScanEnemy, TargetNearestEnemy:
	TargetPriorityHighlight	= 'MouseTurn',
	Mouselook     = 'MouseTurn',      -- Capture addons' usage and take into account.
	-- MoveForwardTurns = 'MouseTurn',

	MoveForward		= 'MoveKeys',
	MoveBackward	= 'MoveKeys',
	StrafeLeft		= 'MoveKeys',
	StrafeRight		= 'MoveKeys',
}

--[[
-- commandGroups:  `false` value here means 'not pressed'
IA.commandGroups = {
	Turn       = { TurnLeft=false, TurnRight=false },
	Pitch      = { PitchUp=false, PitchDown=false },
	MoveKeys   = { MoveForward=false, MoveBackward=false, StrafeLeft=false, StrafeRight=false },
	Mouselook  = { MoveAndSteer=true, TargetPriorityHighlight=true },  --, TurnOrAction=true }, -- false in ActionMode
}
--]]

local DisablesAutoRun = {
	MoveAndSteer	= 1,
	MoveForward	  = 1,
	MoveBackward	= 1,
}




------------------
-- Enable state
------------------

function IA:GetActiveActionMode()
	local actives = self.activeCommands
	return  actives.ActionModeRecent  or  not actives.ActionModeTempCam and not actives.TempCursor and not actives.WindowOnScreen and actives.ActionMode
end

function IA:SetActionMode(enable, permanent)
	local actives = self.activeCommands
	if permanent then  actives.ActionMode = enable  end
	actives.ActionModeTempCam = not enable  and  not permanent
	actives.ActionModeRecent = enable and actives.ActionMode
	self.UserBindings:UpdateActionModeBindings()
end

IA.SetActionModeTemp = IA.SetActionMode

--[[
function IA:SetActionModeTemp(enable)
	local actives = self.activeCommands
	if actives.ActionModeRecent == enable then  return  end

	self.activeCommands.ActionModeRecent = enable
	self.activeCommands.ActionModeTempCam = enable==false
	self.UserBindings:UpdateActionModeBindings(enable)
end
--]]

function IA:ResetActionModeRecent()
	self.activeCommands.ActionModeRecent = nil
	self.UserBindings:UpdateActionModeBindings()
end




function  IA:ResetState()
	Log.State(colors.red .. 'RESETing|r keypress state')
	
	-- A command might be stuck in pressed state, reset state to free mouse
	local actives = self.activeCommands
	for  cmdName,pressed  in  pairs(actives)  do  if  pressed  then
		Log.State('  '.. colors.red .. cmdName ..'|r was PRESSED, is reset now')
		-- actives[cmdName] = nil
	end end -- for if
	wipe(actives)
	
	-- Reset group counters
	local groups = self.commandGroups
	for  groupName,group  in  pairs(groups)  do  if  next(group)  then
		local keys = ""
		for k,v in group do  keys = keys..k  end
		Log.State('  Group "'.. colors.yellow .. groupName ..'"|r had "'..keys..'" keys pressed, is reset now')
		wipe(group)
	end end -- for if
end




-------------------------------------
-- State handling `business` logic --
-------------------------------------

function IA:ProcessCommand(cmdName, pressed)
	local actives = self.activeCommands

	cmdName = self:CheckStuckState(cmdName, pressed)
	self:CheckActionMode(cmdName, pressed)

	--[[
	-- TurnOrAction inverts the previous Mouselook state (the state before it was pressed).
	-- The mop client bugs this:  release event of TurnButton (RightButton or any button bound to it) is eliminated by MouselookStop(),
	-- therefore it can happen only when releasing, not inverted (when pressed).
	if cmdName == 'TurnOrAction' then
		if pressed
		-- then  actives.TurnOrActionForcesState = not IA.lastMouselook
		-- then  actives.TurnOrActionForcesState = not actives.ActionMode
		then  actives.TurnOrActionForcesState = true
		else  actives.TurnOrActionForcesState = nil
		end
		-- Note: This is the secure hook ran after TurnOrActionStart(), which just enabled Mouselook,
		-- therefore IsMouselooking() returns true in any case.
	end
	--]]

	self:SetCommandState(cmdName, pressed)
	Log.Command("  IA:ProcessCommand("..IA.coloredKey(cmdName, pressed)..")")

	if pressed and actives.AutoRun then  self:CheckAutoRun(cmdName, pressed)  end
end


------------------------------
--
function IA:CheckStuckState(cmdName, pressed)
	local actives = self.activeCommands
	-- Do not accept multiple keys bound to the same command to be pressed at the same time.
	-- That results in multiple calls with same cmdName, pressed. Press 2 buttons, release 1,
	-- and the client thinks both are released.
	-- Minor issue compared to its counter-case: if a binding is changed mid-button-press,
	-- bliz will release the new binding, not the one that was pressed originally.
	-- This causes stuck keys, stuck MouselookMode, unable to get back the cursor :-D

	if  not pressed == not actives[cmdName]  then
		-- Patch MoveAndSteer press + MouselookOverrideBinding(MoveAndSteer->MoveForward) + MoveForward release
		-- to stop Mouselook started by MoveAndSteer.
		if cmdName == 'MoveForward' and actives.MoveAndSteer then
			Log.Anomaly("  IA:ProcessCommand("..IA.coloredKey(cmdName, pressed)..") - patched to MoveAndSteer")
			cmdName = 'MoveAndSteer'
		else
			local suffix = pressed  and  "key pressed again without being released. Stuck key?"  or  "key released without being pressed before."
			Log.Anomaly("  IA:ProcessCommand("..colors.red..cmdName.."|r):  "..suffix)
		end
	else
  end
	return cmdName
end


------------------------------
--
function IA:CheckActionMode(cmdName, pressed)
	-- Update ActionMode in response to certain inputs, when
	-- it gives a more fluent user experience to disable/enable ActionMode automatically.
	if pressed then
		if  cmdName=='TurnOrAction'  then  self.timeTurnOrAction = GetTime()  end
	else
		if not self.lastMouselook then
			-- Pressing LeftButton (turning the camera) will disable ActionMode temporarily.
			-- If it would stay on, then the first mouse movement would yank your character to the camera direction, without specific command from you.
			-- Clicking the RightButton will still instantly turn the character to the camera direction.
			if  cmdName=='CameraOrSelectOrMove'  and  self.db.profile.disableWithLookAround  and  not SpellIsTargeting()  then
				self:SetActionModeTemp(false)
			end
		else
			-- Pressing RightButton (turning your character) will enable ActionMode, if it was disabled temporarily.
			if  cmdName=='TurnOrAction'  and  self.db.profile.enableAfterTurning
			and  self.timeTurnOrAction  and  0.2 < GetTime() - self.timeTurnOrAction  then
					self.timeTurnOrAction = nil
					self:SetActionModeTemp(true)
			end
			-- Pressing MoveAndSteer will enable ActionMode, if it was disabled temporarily.
			-- It feels fluent to keep turning the character with the mouse, without pressing buttons.
			-- If not, then it can be disabled in settings.
			if  cmdName=='MoveAndSteer'  and  self.db.profile.enableAfterMoveAndSteer  then
				self:SetActionModeTemp(true)
			end
		end
	end
end

------------------------------
-- Check if the game disables AutoRun. By check i mean make an educated guess. Cheers for the api disaigners.
--
function IA:CheckAutoRun(cmdName, pressed)
	local actives = self.activeCommands
	-- Quite a few click/binding combos disable AutoRun. Try to detect *all* such combinations.
	-- Ex. AutoRun + B1 + B2 -> AutoRun stops, activeCommands.AutoRun is stuck opposite of the real.
	-- AutoRun + MoveAndSteer (out-of-combat remapped to TurnWithoutAction)
	-- Checking GetUnitSpeed() is still there to catch any unforeseen corner cases.
	-- Credits for the idea:  https://wow.curseforge.com/projects/mouselookhandler/pages/mouselook-while-moving-including-autorun
	if actives.CameraOrSelectOrMove and IA.IsMouselooking()
	or DisablesAutoRun[cmdName]    -- Forward/backward movement disables AutoRun.
	then  self:SetCommandState('AutoRun', false)
	elseif 0 == GetUnitSpeed('player') then
		self:SetCommandState('AutoRun', false)
		Log.Anomaly("  IA:ProcessCommand("..IA.coloredKey(cmdName, pressed).."):  Disabled activeCommands."..colors.AutoRun.."AutoRun|r, state would have been inverted, and MoveAndSteer rebinding to TurnWithoutAction stuck.")
	end
end


------------------------------
-- Store command's active state and update it's group's state.
--
function IA:SetCommandState(cmdName, active)
	-- Set command active state. This changes the result of IA:ExpectedMouselook().
	self.activeCommands[cmdName] = active

	-- Update group state.
	local groupName = self.commandGrouping[cmdName]
	if  groupName  then  self:SetGroupCommand(groupName, cmdName, active)  end

	-- Update bindings.
	if cmdName=='AutoRun' then  IA.OverrideBindings:UpdateOverrides()  end

	return true
end


function IA:SetGroupCommand(groupName, cmdName, active)
	local group = self.commandGroups[groupName]
	group[cmdName] = active or nil
	self.activeCommands[groupName] = next(group)
end




-------------------------------------------
-- Control and debug new Mouselook state --
-------------------------------------------

function  IA:UpdateMouselook(possibleTransition, event)
	event = event  or  'nil'
	local currentState = not not IA.IsMouselooking()
	local outsideChange = self.lastMouselook ~= currentState
	
	-- Report modified IsMouselooking() to catch commands changing it. Like  MoveAndSteerStart  and  TurnOrActionStart
	if  outsideChange  and  currentState ~= self.commandsChangingMouselook[event]  then
		Log.Anomaly('  '.. colors.red .. event .. '|r changed Mouselook: '.. colorBoolStr(self.lastMouselook, true) ..'->'.. colorBoolStr(currentState, true) )
	end
	
	local expState, reason = self:ExpectedMouselook()
	if  possibleTransition ~= nil  and  expState ~= possibleTransition  and  expState ~= currentState  and  not outsideChange  then
		Log.Anomaly('  IA:Update('.. event:sub(1,16) ..'):  '.. colors.yellow .. reason ..'|r->'.. colorBoolStr(expState, colors.red)  ..' is not possibleTransition='.. colorBoolStr(possibleTransition))
	end
	
	-- Report every update, reason and result for debugging
	-- Show state in red if it was outsideChange (the command or other event changed it)
	local stateColor = (expState ~= currentState)  or  outsideChange and colors.red
	
	local stateStr = colorBoolStr(expState, stateColor)
	local prefix = 'IA:Update('.. colorBoolStr(possibleTransition) ..','.. colors.event .. event:sub(1,16) ..'|r):  '
	--local suffix = colors.lightblue .. reason ..'|r->'.. stateStr .. '|n------'
	local suffix = reason ..'->'.. stateStr			-- .. '|n------'
	
	if  (self.lastMouselook ~= expState)  or  outsideChange
  then  Log.State(prefix .. suffix)
	else  Log.Update(prefix .. suffix)
  end
	self.lastMouselook = expState
	
	-- Commit the change
	if  expState ~= currentState  then
		if  expState  then  IA.MouselookStart()  else  IA.MouselookStop()  end
	end
end

IA.lastMouselook = not not IsMouselooking()



-------------------------------------
--- IA:ExpectedMouselook() implements the brainstem of ImmersiveAction:
-- 
-- Calculates the effective Mouselook state in a declarative manner,
-- based on 13 game state parameters collected from user actions and game events.
-- The evaluation order is a delicate priority crafted to get the
-- most fluent result ganeplay-wise in every circumstance.
-- 2^13 = 8k distinct inputs include many corner cases and quirks of the wow client.
-- In short: it can be broken by looking at it the wrong way.
--
function IA:ExpectedMouselook()
	-- local groups = self.commandGroups
	local actives = self.activeCommands
	
	-- Decide which one is more important if commands are conflicting:
	
	-- Turn,Pitch is first in priority:
	-- Requires Mouselook OFF to actually turn the character.
	-- With Mouselook ON it acts as Strafe,Move, which is very unexpected, and usually happens at the worst time, like standing on the edge of a cliff.
	if  actives.Turn   then  return false, actives.Turn   end
	if  actives.Pitch  then  return false, actives.Pitch  end
	
	-- CameraOrSelectOrMove (LeftButton, B1) + TurnOrAction (RightButton, B2)  requires Mouselook ON to actually move the character.
	-- local moveWithCameraButton =  actives.CameraOrSelectOrMove  and  actives.ActionMode  and  self.db.profile.actionModeMoveWithCameraButton
	-- if  moveWithCameraButton  then  return not actives.TurnOrAction, 'moveWithCameraButton'  end

	-- TurnOrAction (RightButton) enables Mouselook state.
	-- Tried to invert the Mouselook state, and found that wow 5.4.8 silently eliminates the RightButton release event:
	-- OnMouseUp(RightButton) is not called if RightButton was pressed when Mouselook was active. This might be fixed in Legion.
	-- TurnOrAction takes precedence over WindowOnScreen, SpellIsTargeting, CursorPickup, MoveAndSteer and modifiers (Shift/Ctrl/Alt).
	-- As long as the user is pressing the RightButton those do not matter, nor effect the behaviour.
	if  actives.TurnOrAction then  return true, 'TurnOrAction'  end

	-- In ActionMode (enables Mouselook mode) the LeftButton would do MoveAndSteer instead of FreeCameraMode,
	-- just like when both buttons are pressed. To enter FreeCameraMode we disable MouselookMode.
	if  actives.CameraOrSelectOrMove  then  return false, 'CameraOrSelectOrMove'  end

	-- ReleaseCursor command.
	if  actives.MouseCursor  then  return false, "MouseCursor: "..actives.MouseCursor  end

	-- MoveAndSteer,TargetScanEnemy,TargetNearestEnemy takes precedence over WindowOnScreen, SpellIsTargeting and CursorPickup.
	-- Maybe all Move,Strafe bound to mouse button should do so. WorldClickHandler could do that.
	if  actives.MouseTurn  then  return true, "MouseTurn: "..tostring(actives.MouseTurn)  end		-- 'TurnWithoutInteract, MoveAndSteer, ScanEnemy' , addons using MouselookStart()  end

	if  actives.disableModPressed  then  return false, 'disableModPressed'  end
	if  actives.enableModPressed   then  return true,  'enableModPressed'   end


	-- State that is not currently pressed, but the result of an earlier button press (and release). These have a dynamic priority: the last one pressed takes precedence.

	-- Any new event: SpellIsTargeting, CursorPickup, new WindowOnScreen will delete ActionModeRecent.
	if  actives.ActionModeRecent   then  return true,  'ActionModeRecent'   end
	if  actives.ActionModeTempCam  then  return false, 'ActionModeTempCam'  end

	-- Cursor actions:
	if  SpellIsTargeting()	then  return false, 'SpellIsTargeting'  end
	if  GetCursorInfo()		  then  return false, 'CursorPickup'      end
	-- if  actives.TempCursor  then  return false, 'TempCursor'        end

	-- WindowOnScreen is higher priority than  enableWithMoveKeys:Move,Strafe. One can click on windows while moving with QWES / WASD.
	if  actives.WindowOnScreen  then  return false, "WindowOnScreen: "..actives.WindowOnScreen  end

	-- Move,Strafe commands enable if enableWithMoveKeys and no WindowOnScreen.
	if  actives.MoveKeys  and  self.db.profile.enableWithMoveKeys  then
		return true, "enableWithMoveKeys: "..actives.MoveKeys
	end

	-- Lowest priority as a static setting:  ActionMode.
	if  actives.ActionMode  then  return actives.ActionMode, 'ActionMode'  end

	-- By default Mouselook is off.
	return  false, 'NoAction'
end



