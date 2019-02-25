-- Methods for event handling, commandState update of IA, Mouselook, SmartTargeting
local _G, ADDON_NAME, _ADDON = _G, ...
local IA = _G.ImmersiveAction or {}  ;  _G.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log
local colorBoolStr = IA.colorBoolStr
local colors = IA.colors

IA.commandState = {}

--[[
-- commandGroups:  `false` value here means 'not pressed'
IA.commandGroups = {
	Turn       = { TurnLeft=false, TurnRight=false },
	Pitch      = { PitchUp=false, PitchDown=false },
	MoveKeys   = { MoveForward=false, MoveBackward=false, StrafeLeft=false, StrafeRight=false },
	Mouselook  = { MoveAndSteer=true, TargetPriorityHighlight=true },  --, TurnOrAction=true }, -- false in ActionMode
}
--]]
-- commandGroups:  `nil` is 'not pressed'
IA.commandGroups = {
	Turn       = {},
	Pitch      = {},
	MoveKeys   = {},
	Mouselook  = {},
}

--[[ Analyzing key press state:
-- commands can get stuck in pressed state if the binding is changed and the "up" event goes to a different command
/dump ImmersiveAction.db.profile.enabledOnLogin
/dump ImmersiveAction.commandState, ImmersiveAction.commandGroups
/run ImmersiveAction:ResetState()
-- Cause of ImmersiveAction:
/dump ImmersiveAction.db.profile.enableWithMoveKeys
/dump ImmersiveAction:ExpectedMouselook()
/dump ImmersiveAction.WindowsOnScreen
-- Overridden bindings:

/dump ImmersiveAction.MouselookOverrideBindings= {}
/dump ImmersiveAction.MoveAndSteerKeys= {}

-- Settings:
/dump ImmersiveAction.db.profile
/dump ImmersiveActionDB
-- Explicit:
/run ImmersiveAction:ResetState()
/run MouselookStart()
/run MouselookStop()
/dump 'Me:'..(UnitIsPVP('player') and 'PvP' or 'non-pvp'), UnitName('target')..':'..(UnitIsPVP('target') and 'PvP' or 'non-pvp')
--]]




------------------
-- Enable state
------------------

function IA:SetActionMode(enable)
	local cstate = self.commandState
	if cstate.ActionModeRecent == enable then  return  end
	cstate.ActionModeRecent = enable
	cstate.ActionMode = enable
	self:OverrideCommandsIn('ActionMode', enable)
end




function  IA:ResetState()
	Log.State(colors.red .. 'RESETing|r keypress state')
	
	-- A command might be stuck in pressed state, reset state to free mouse
	local cstate = self.commandState
	for  cmdName,pressed  in  pairs(cstate)  do  if  pressed  then
		Log.State('  '.. colors.red .. cmdName ..'|r was PRESSED, is reset now')
		-- cstate[cmdName]= nil
	end end -- for if
	wipe(cstate)
	
	-- Reset group counters
	local groups= self.commandGroups
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

function IA:SetCommandState(cmdName, pressed)
	-- Do not accept multiple keys bound to the same command to be pressed at the same time.
	-- That results in multiple calls with same cmdName, pressed. Press 2 buttons, release 1,
	-- and the client thinks both are released.
	-- Minor issue compared to its counter-case: if a binding is changed mid-button-press,
	-- bliz will release the new binding, not the one that was pressed originally.
	-- This causes stuck keys, stuck MouselookMode, unable to get back the cursor :-D
	local keystate =  pressed  and  'down'  or  'up'
	local cstate = self.commandState

	if  not pressed == not cstate[cmdName]  then
		-- Patch MoveAndSteer press + MouselookOverrideBinding(MoveAndSteer->MoveForward) + MoveForward release
		-- to stop Mouselook started by MoveAndSteer.
		if cmdName == 'MoveForward' and cstate.MoveAndSteer then
			Log.Anomaly("  CM - SetCommandState(".. IA.colors[keystate] .. cmdName .." ".. keystate:upper() .."|r) - patched to MoveAndSteer")
			cmdName = 'MoveAndSteer'
		else
			return false
		end
	else
		if cmdName == 'MoveForward' and GetMouseButtonClicked() then
			Log.Anomaly("  CM - SetCommandState(".. IA.colors[keystate] .. cmdName .." ".. keystate:upper() .."|r) - patched to MoveAndSteer")
			cmdName = 'MoveAndSteer'
		end
  end
	
	-- TurnOrAction inverts the previous Mouselook state (the state before it was pressed).
	if cmdName == 'TurnOrAction' then
		if pressed
		then  cstate.TurnOrActionForcesState = not IA.lastMouselook
		else  cstate.TurnOrActionForcesState = nil
		end
		-- Note: This is the secure hook ran after TurnOrActionStart(), which just enabled Mouselook,
		-- therefore IsMouselooking() returns true in any case.
	end

	-- Update ActionMode to retain lastMouselook after specific buttons were pressed.
	if not pressed then
		if not IA.lastMouselook then
			-- Clicking LeftButton (turning the camera away from the direction your character looks) will disable ActionMode.
			if  cmdName=='CameraOrSelectOrMove'  and  IA.disableWithLookAround  then  IA:SetActionMode(false)  end
		else
			-- After pressing MoveAndSteer:  ActionMode will stay enabled.
			if  cmdName=='MoveAndSteer' and  IA.enableAfterMoveAndSteer  then  IA:SetActionMode(true)  end
			-- After pressing LeftButton and RightButton together:  ActionMode will stay enabled.
			-- Rule:  one button released while the other is pressed.
			if IA.enableAfterBothButtons then
				if  cmdName=='CameraOrSelectOrMove' and self.TurnOrAction
				or  cmdName=='TurnOrAction' and self.CameraOrSelectOrMove
				then  IA:SetActionMode(true)  end
			end
		end
	end
	
	-- Set command pressed state. This changes the result of IA:ExpectedMouselook().
	cstate[cmdName]= pressed

	-- Update group state.
	local groupName= self.commandsHooked[cmdName]
	if  groupName  then  self:SetGroupCommand(groupName, cmdName, pressed)  end

	-- Update bindings.
	if cmdName=='AutoRun' then  IA:OverrideCommandsIn(cmdName, pressed)  end

	return true
end


function IA:SetGroupCommand(groupName, cmdName, pressed)
	local group= self.commandGroups[groupName]
	group[cmdName] = pressed or nil
	cstate[groupName] = next(group)
end




-------------------------------------------
-- Control and debug new Mouselook state --
-------------------------------------------

function  IA:UpdateMouselook(possibleTransition, event)
	event= event  or  'nil'
	local currentState= not not IsMouselooking()
	local outsideChange= self.lastMouselook ~= currentState
	
	-- Report modified IsMouselooking() to catch commands changing it. Like  MoveAndSteerStart  and  TurnOrActionStart
	if  outsideChange  and  currentState ~= self.commandsChangingMouselook[event]  then
		Log.Anomaly('  '.. colors.red .. event .. '|r changed Mouselook: '.. colorBoolStr(self.lastMouselook, true) ..'->'.. colorBoolStr(currentState, true) )
	end
	
	local expState, reason= self:ExpectedMouselook()
	if  possibleTransition ~= nil  and  expState ~= possibleTransition  and  expState ~= currentState  and  not outsideChange  then
		Log.Anomaly('  CM:Update('.. event:sub(1,16) ..'):  '.. colors.yellow .. reason ..'|r->'.. colorBoolStr(expState, colors.red)  ..' is not possibleTransition='.. colorBoolStr(possibleTransition))
	end
	
	-- Report every update, reason and result for debugging
	-- Show state in red if it was outsideChange (the command or other event changed it)
	local stateColor= (expState ~= currentState)  or  outsideChange and colors.red
	
	local stateStr= colorBoolStr(expState, stateColor)
	local prefix= 'CM:Update('.. colorBoolStr(possibleTransition) ..','.. colors.event .. event:sub(1,16) ..'|r):  '
	--local suffix= colors.lightblue .. reason ..'|r->'.. stateStr .. '|n------'
	local suffix= reason ..'->'.. stateStr			-- .. '|n------'
	
	if  (self.lastMouselook ~= expState)  or  outsideChange
  then  Log.State(prefix .. suffix)
	else  Log.Update(prefix .. suffix)
  end
	self.lastMouselook= expState
	
	-- Commit the change
	if  expState ~= currentState  then
    if  SpellIsTargeting()  then
			print(prefix .. suffix .. "  SpellIsTargeting():  Mouselook change might prevent casting the spell.")
			-- TODO: remove print. Spell targeting does nothing? The improved priority order in ExpectedMouselook() might have fixed this.
			return
		end
		if  expState  then  IA.MouselookStart()  else  IA.MouselookStop()  end
		--self.lastMouselookSet= expState
	end
end

IA.lastMouselook= not not IsMouselooking()
--IA.lastMouselookSet= false



-------------------------------------
--- IA:ExpectedMouselook() implements the brainstem of ImmersiveAction:
-- 
-- Calculates the effective Mouselook state in a declarative manner,
-- based on 13 game state parameters collected from user actions and game events.
-- The evaluation order is a delicate priority crafted to get the most
-- natural result in every circumstance. 2^13 = 8k distinct inputs
-- include many corner cases and quirks of the wow client.
-- In one word: it can be broken by looking at it the wrong way.
--
function IA:ExpectedMouselook()
	-- local groups = self.commandGroups
	local cstate = self.commandState
	
	-- Turn,Pitch is first in priority:
	-- Requires Mouselook OFF to actually turn the character.
	-- With Mouselook ON it acts as Strafe,Move, which is very unexpected, and usually happens at the worst time, like standing on the edge of a cliff.
	if  cstate.Turn   then  return false, cstate.Turn   end
	if  cstate.Pitch  then  return false, cstate.Pitch  end
	
	-- CameraOrSelectOrMove (LeftButton, B1) + TurnOrAction (RightButton, B2)  requires Mouselook ON to actually move the character.
	-- This will be done using TurnOrActionForcesState, which takes care of a special case:
	-- In ActionMode B2+B1=Cursor+Camera (order matters) inverts MouselookMode to FreeCameraMode, allowing look-around. 
	-- To move press B1 or B1+B2 (depending on actionModeMoveWithCameraButton).

	-- TurnOrAction (RightButton) will _invert_ the Mouselook state active at the time it is pressed.
	-- It takes precedence over WindowsOnScreen, SpellIsTargeting, CursorPickedUp, MoveAndSteer and modifiers (Shift/Ctrl/Alt).
	-- As long as you press the RightButton those do not matter, nor effect the behaviour.
	if  nil~=cstate.TurnOrActionForcesState  then  return cstate.TurnOrActionForcesState, 'TurnOrAction'  end

	-- In ActionMode (enables MouselookMode) the LeftButton would do MoveAndSteer instead of FreeCameraMode,
	-- just like when both buttons are pressed. To enter FreeCameraMode we disable MouselookMode.
	-- Except when the user requested that LeftButton moves in ActionMode.
	-- Note: in this case pressing the RightButton _first_ will set TurnOrActionForcesState = false,
	-- then pressing LeftButton will return `false` in the above line, and enable FreeCameraMode. Uff.
	local freeCamera =  cstate.CameraOrSelectOrMove  and  not (cstate.ActionMode and self.db.profile.actionModeMoveWithCameraButton)
	if  freeCamera  then  return false, 'CameraOrSelectOrMove'  end

	-- MoveAndSteer,TargetScanEnemy,TargetNearestEnemy takes precedence over WindowsOnScreen, SpellIsTargeting and CursorPickedUp.
	-- Maybe all Move,Strafe bound to mouse button should do so. In that case extra logic is needed to detect when Move is caused by a mouse button.
	if  cstate.Mouselook  then  return true, "Mouselook:"..cstate.Mouselook  end		-- 'MoveAndSteer, ScanEnemy', addons using MouselookStart()  end

	if  cstate.enableModPressed   then  return true,  'enableModPressed'   end
	if  cstate.disableModPressed  then  return false, 'disableModPressed'  end

	-- Any new event: SpellIsTargeting, CursorPickedUp, new WindowsOnScreen will delete ActionModeRecent.
	if  nil~=cstate.ActionModeRecent  then  return cstate.ActionModeRecent, 'ActionModeRecent'  end

	-- Cursor actions:
	if  cstate.SpellIsTargeting	then  return false, 'SpellIsTargeting'  end
	if  cstate.CursorPickedUp		then  return false, 'CursorPickedUp'    end
	--if  cstate.CursorObjectOrSpellTargeting  then  return false, 'CursorObjectOrSpellTargeting'  end

	-- WindowsOnScreen are higher priority than  enableWithMoveKeys:Move,Strafe.
	-- if  self:CheckForFramesOnScreen()  then  return false, 'WindowsOnScreen'  end
	if  0 < #IA.WindowsOnScreen  then  return false, 'WindowsOnScreen:'..(IA.WindowsOnScreen[1]:GetName() or "<noname>")  end

	-- Move,Strafe commands enable if enableWithMoveKeys and no WindowsOnScreen.
	if  self.db.profile.enableWithMoveKeys  and  cstate.MoveKeys  then
		return true, "enableWithMoveKeys:"..cstate.MoveKeys
	end

	-- Lowest priority as a static setting:  ActionMode.
	if  cstate.ActionMode  then  return cstate.ActionMode, 'ActionMode'  end

	-- By default Mouselook is off.
	return  false, 'NoAction'
end



