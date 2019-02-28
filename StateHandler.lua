-- Methods for event handling, commandState update of IA, Mouselook, SmartTargeting
local GL, ADDON_NAME, ADDON = _G, ...
local IA = GL.ImmersiveAction or {}  ;  GL.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log
local colorBoolStr = IA.colorBoolStr
local colors = IA.colors

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


------------------------------
--- IA.commandState is the key/binding/command pressed state map (action->pressed).
-- This is the input to IA:ExpectedMouselook().
-- IA:ProcessCommand() keeps this updated with UI actions/events.
--
IA.commandState = {}

-- commandGroups:  `nil` is 'not pressed'
IA.commandGroups = {
	Turn       = {},
	Pitch      = {},
	MoveKeys   = {},
	MouseTurn  = {},
	MouseCursor= {},
}

IA.commandGrouping = {
	TurnLeft			= 'Turn',
	TurnRight			= 'Turn',
	PitchUp				= 'Pitch',
	PitchDown			= 'Pitch',

	CameraOrSelectOrMove = false,  -- Not always MouseCursor:  actionModeMoveWithCameraButton needs Mouselook to make it move.
	-- CameraOrSelectOrMove = 'MouseCursor',  -- If actionModeMoveWithCameraButton rebinds LeftButton to MoveForward, then this is cleanly MouseCursor.
	TurnOrAction	= 'MouseTurn',
	-- TurnOrAction	= false,            -- Custom: sets Mouselook to inverse of lastMouselook.
	TurnWithoutInteract = 'MouseTurn',
	ReleaseCursor       = 'MouseCursor',

	MoveAndSteer	= 'MouseTurn',
	-- TargetScanEnemy, TargetNearestEnemy:
	TargetPriorityHighlight	= 'MouseTurn',
	Mouselook     = 'MouseTurn',      -- Capture addons' usage and take into account.

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

function IA:SetActionMode(enable)
	local cstate = self.commandState
	if cstate.ActionModeRecent == enable then  return  end
	cstate.ActionModeRecent = enable
	cstate.ActionMode = enable
	self.OverrideBindings:UpdateOverrides()
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
	local cstate = self.commandState

	-- if cmdName == 'MoveForward' and GetMouseButtonClicked() then
	if cmdName == 'MoveForward' then
		-- Log.Anomaly("  IA:ProcessCommand("..IA.coloredKey(cmdName, pressed)..") - patched to MoveAndSteer, GetMouseButtonClicked()="..tostring(GetMouseButtonClicked()))
		cmdName = 'MoveAndSteer'
	end

	if pressed and cstate.AutoRun then  self:CheckAutoRun(cmdName, pressed)  end
	cmdName = self:CheckStuckState(cmdName, pressed)
	self:CheckActionMode(cmdName, pressed)

	--[[
	-- TurnOrAction inverts the previous Mouselook state (the state before it was pressed).
	if cmdName == 'TurnOrAction' then
		if pressed
		-- then  cstate.TurnOrActionForcesState = not IA.lastMouselook
		-- then  cstate.TurnOrActionForcesState = not cstate.ActionMode
		then  cstate.TurnOrActionForcesState = true
		else  cstate.TurnOrActionForcesState = nil
		end
		-- Note: This is the secure hook ran after TurnOrActionStart(), which just enabled Mouselook,
		-- therefore IsMouselooking() returns true in any case.
	end
	--]]

	self:SetCommandState(cmdName, pressed)
	Log.Command("  IA:ProcessCommand("..IA.coloredKey(cmdName, pressed)..")")
end


------------------------------
--
function IA:CheckStuckState(cmdName, pressed)
	local cstate = self.commandState
	-- Do not accept multiple keys bound to the same command to be pressed at the same time.
	-- That results in multiple calls with same cmdName, pressed. Press 2 buttons, release 1,
	-- and the client thinks both are released.
	-- Minor issue compared to its counter-case: if a binding is changed mid-button-press,
	-- bliz will release the new binding, not the one that was pressed originally.
	-- This causes stuck keys, stuck MouselookMode, unable to get back the cursor :-D

	if  not pressed == not cstate[cmdName]  then
		-- Patch MoveAndSteer press + MouselookOverrideBinding(MoveAndSteer->MoveForward) + MoveForward release
		-- to stop Mouselook started by MoveAndSteer.
		if cmdName == 'MoveForward' and cstate.MoveAndSteer then
			Log.Anomaly("  IA:ProcessCommand("..IA.coloredKey(cmdName, pressed)..") - patched to MoveAndSteer")
			cmdName = 'MoveAndSteer'
		else
			local suffix= pressed  and  "key pressed again without being released. Stuck key?"  or  "key released without being pressed before."
			Log.Anomaly("  IA:ProcessCommand("..colors.red..cmdName.."|r):  "..suffix)
		end
	else
  end
	return cmdName
end


------------------------------
-- Check if the game disables AutoRun. By check i mean make an educated guess. Cheers for the api disaigners.
--
function IA:CheckAutoRun(cmdName, pressed)
	local cstate = self.commandState
	-- Quite a few click/binding combos disable AutoRun. Try to detect *all* such combinations.
	-- Ex. AutoRun + B1 + B2 -> AutoRun stops, commandState.AutoRun is stuck opposite of the real.
	-- AutoRun + MoveAndSteer (out-of-combat remapped to TurnWithoutAction)
	-- Checking GetUnitSpeed() is still there to catch any unforeseen corner cases.
	-- Credits for the idea:  https://wow.curseforge.com/projects/mouselookhandler/pages/mouselook-while-moving-including-autorun
	if cmdName=='CameraOrSelectOrMove' and cstate.TurnOrAction
	or cmdName=='TurnOrAction' and cstate.CameraOrSelectOrMove
	or DisablesAutoRun[cmdName]    -- Forward/backward movement disables AutoRun.
	then  self:SetCommandState('AutoRun', false)
	elseif 0 == GetUnitSpeed('player') then
		self:SetCommandState('AutoRun', false)
		Log.Anomaly("  IA:ProcessCommand("..IA.coloredKey(cmdName, pressed).."):  Disabled commandState."..colors.AutoRun.."AutoRun|r, state would have been inverted, and MoveAndSteer rebinding to TurnWithoutAction stuck.")
	end
end


------------------------------
--
function IA:CheckActionMode(cmdName, pressed)
	-- Update ActionMode in response to certain inputs, when
	-- it gives a more fluent user experience to disable/enable ActionMode automatically.
	if not pressed then
		if not IA.lastMouselook then
			-- Turning the camera away from the direction your character looks (clicking LeftButton) will disable ActionMode.
			-- If it stays on the first mouse movement will yank your character to the camera direction, without specific command from you.
			-- Clicking the RightButton will still instantly turn the character to the camera direction.
			if  cmdName=='CameraOrSelectOrMove'  and  IA.disableWithLookAround  then  IA:SetActionMode(false)  end
		else
			-- After pressing MoveAndSteer:  enable ActionMode, it feels fluent to keep turning the character with the mouse, without pressing buttons.
			-- If not, then it can be disabled in settings.
			if  cmdName=='MoveAndSteer' and  IA.enableAfterMoveAndSteer  then  IA:SetActionMode(true)  end
			-- After pressing LeftButton and RightButton together:  ActionMode will stay enabled.
			-- It's the same as MoveAndSteer but with two buttons. Can be enabled separately.
			-- Rule:  one button released while the other is pressed.
			if IA.enableAfterBothButtons then
				if  cmdName=='CameraOrSelectOrMove' and self.TurnOrAction
				or  cmdName=='TurnOrAction' and self.CameraOrSelectOrMove
				then  IA:SetActionMode(true)  end
			end
		end
	end
end


------------------------------
-- Store command's active state and update it's group's state.
--
function IA:SetCommandState(cmdName, active)
	-- Set command active state. This changes the result of IA:ExpectedMouselook().
	self.commandState[cmdName] = active

	-- Update group state.
	local groupName = self.commandsHooked[cmdName]
	if  groupName  then  self:SetGroupCommand(groupName, cmdName, active)  end

	-- Update bindings.
	if cmdName=='AutoRun' then  IA.OverrideBindings:UpdateOverrides()  end

	return true
end


function IA:SetGroupCommand(groupName, cmdName, active)
	local group= self.commandGroups[groupName]
	group[cmdName] = active or nil
	self.commandState[groupName] = next(group)
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
		Log.Anomaly('  IA:Update('.. event:sub(1,16) ..'):  '.. colors.yellow .. reason ..'|r->'.. colorBoolStr(expState, colors.red)  ..' is not possibleTransition='.. colorBoolStr(possibleTransition))
	end
	
	-- Report every update, reason and result for debugging
	-- Show state in red if it was outsideChange (the command or other event changed it)
	local stateColor= (expState ~= currentState)  or  outsideChange and colors.red
	
	local stateStr= colorBoolStr(expState, stateColor)
	local prefix= 'IA:Update('.. colorBoolStr(possibleTransition) ..','.. colors.event .. event:sub(1,16) ..'|r):  '
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
-- The evaluation order is a delicate priority crafted to get the
-- most fluent result ganeplay-wise in every circumstance.
-- 2^13 = 8k distinct inputs include many corner cases and quirks of the wow client.
-- In short: it can be broken by looking at it the wrong way.
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
	-- if  nil~=cstate.TurnOrActionForcesState  then  return cstate.TurnOrActionForcesState, 'TurnOrAction'  end
	if  cstate.TurnOrAction then  return true , 'TurnOrAction'      end
	if  cstate.MouseCursor  then  return false, cstate.MouseCursor  end

	-- In ActionMode (enables MouselookMode) the LeftButton would do MoveAndSteer instead of FreeCameraMode,
	-- just like when both buttons are pressed. To enter FreeCameraMode we disable MouselookMode.
	-- Except when the user requested that LeftButton moves in ActionMode.
	-- Note: in this case pressing the RightButton _first_ will set TurnOrActionForcesState = false,
	-- then pressing LeftButton will return `false` in the above line, and enable FreeCameraMode. Uff.
	local freeCamera =  cstate.CameraOrSelectOrMove  and  not (cstate.ActionMode and self.db.profile.actionModeMoveWithCameraButton)
	if  freeCamera  then  return false, 'CameraOrSelectOrMove'  end

	-- MoveAndSteer,TargetScanEnemy,TargetNearestEnemy takes precedence over WindowsOnScreen, SpellIsTargeting and CursorPickedUp.
	-- Maybe all Move,Strafe bound to mouse button should do so. In that case extra logic is needed to detect when Move is caused by a mouse button.
	if  cstate.MouseTurn  then  return true, "MouseTurn:"..tostring(cstate.MouseTurn)  end		-- 'MoveAndSteer, ScanEnemy', addons using MouselookStart()  end

	if  cstate.enableModPressed   then  return true,  'enableModPressed'   end
	if  cstate.disableModPressed  then  return false, 'disableModPressed'  end

	-- Any new event: SpellIsTargeting, CursorPickedUp, new WindowsOnScreen will delete ActionModeRecent.
	if  nil~=cstate.ActionModeRecent  then  return cstate.ActionModeRecent, 'ActionModeRecent'  end

	-- Cursor actions:
	if  cstate.SpellIsTargeting	then  return false, 'SpellIsTargeting'  end
	if  cstate.CursorPickedUp		then  return false, 'CursorPickedUp'    end
	--if  cstate.CursorObjectOrSpellTargeting  then  return false, 'CursorObjectOrSpellTargeting'  end

	-- WindowsOnScreen are higher priority than  enableWithMoveKeys:Move,Strafe.
	-- if  self:AnyFramesOnScreen()  then  return false, 'WindowsOnScreen'  end
	local frame = IA:AnyFramesOnScreen()
	if  frame  then  return false, 'WindowsOnScreen:'..tostring(frame.GetName and frame:GetName() or frame)  end

	-- Move,Strafe commands enable if enableWithMoveKeys and no WindowsOnScreen.
	if  self.db.profile.enableWithMoveKeys  and  cstate.MoveKeys  then
		return true, "enableWithMoveKeys:"..cstate.MoveKeys
	end

	-- Lowest priority as a static setting:  ActionMode.
	if  cstate.ActionMode  then  return cstate.ActionMode, 'ActionMode'  end

	-- By default Mouselook is off.
	return  false, 'NoAction'
end



