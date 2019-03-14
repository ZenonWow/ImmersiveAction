local G, ADDON_NAME, ADDON = _G, ...
local IA = G.ImmersiveAction or {}  ;  G.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log


-- TODO: pet battle handling

----------------------
-- Command bindings --
----------------------

-- Label visible in key bindings UI.
BINDING_HEADER_ImmersiveAction    = "Immersive Action"

-- Custom commands
BINDING_NAME_INTERACTNEAREST      = "Target and interact closest friendly npc"
BINDING_NAME_ToggleActionMode     = "Toggle Action mode"
BINDING_NAME_ReleaseCursor        = "Release cursor"
BINDING_NAME_TurnWithoutInteract  = "Turn without Interacting"
BINDING_NAME_InvertMouselook      = "Invert mouselook"

-- Builtin commands without a description
BINDING_NAME_CAMERAORSELECTORMOVE = "Rotate Camera     (LeftButton default)"
BINDING_NAME_TURNORACTION 				= "Turn or Interact (RightButton default)"


------------------------------------------
-- Model of commands, declarative style --
------------------------------------------

-- Save original MouselookStart, then securehook the global to catch addon usage.
IA.IsMouselooking = G.IsMouselooking
IA.MouselookStart = G.MouselookStart
IA.MouselookStop  = G.MouselookStop

IA.commandsHooked = {
	TurnLeft			= 'Turn',
	TurnRight			= 'Turn',
	PitchUp				= 'Pitch',
	PitchDown			= 'Pitch',

	CameraOrSelectOrMove = 'MouseCursor',
	CameraOrSelectOrMove = false,
	TurnOrAction	= 'MouseTurn',
	-- TurnOrAction	= false,            -- Custom: sets Mouselook to inverse of lastMouselook.

	MoveAndSteer	= 'MouseTurn',
	-- TargetScanEnemy, TargetNearestEnemy:
	TargetPriorityHighlight	= 'MouseTurn',
	Mouselook     = 'MouseTurn',      -- Capture addons' usage and take into account.

	MoveForward		= 'MoveKeys',
	MoveBackward	= 'MoveKeys',
	StrafeLeft		= 'MoveKeys',
	StrafeRight		= 'MoveKeys',
}

local CommandStopFunc = {
	TargetPriorityHighlight	= G.TargetPriorityHighlightStart and 'TargetPriorityHighlightEnd' or false,
}

--[[
local StopsAutoRun = {
	MoveAndSteerStart	= 1,
	MoveForwardStart	= 1,
	MoveBackwardStart	= 1,
}
--]]

--[[
TurnOrAction, MoveAndSteer, TargetPriorityHighlight  start Mouselook when pushed and stop it when released.
These are the only commands/functions altering Mouselook that I found.
All other functions altering Mouselook will be logged as anomaly.
Sidenote:  when  ActionMode == true  then we want Mouselook to stay ON after releasing these keys,
therefore UpdateMouselook() will override the effect of the Stop functions.
--]]
IA.commandsChangingMouselook = {
	TurnOrActionStart	= true,
	TurnOrActionStop	= false,
	MoveAndSteerStart	= true,
	MoveAndSteerStop	= false,
	-- TargetScanEnemy, TargetNearestEnemy:
	TargetPriorityHighlightStart	= true,
	TargetPriorityHighlightEnd		= false,
}




----------------------------------
-- The entry point of all hooks --
----------------------------------

local UniqueHooks = {}
function UniqueHooks.ToggleAutoRun()  IA:SetCommandState('AutoRun', not IA.activeCommands.AutoRun)  end
function UniqueHooks.StartAutoRun()  IA:SetCommandState('AutoRun', true)  end
function UniqueHooks.StopAutoRun()  IA:SetCommandState('AutoRun', false)  end
function UniqueHooks.PetMoveTo()  IA:UpdateTempCursor('PetMoveTo')  end    -- Pet move targeting.
-- function UniqueHooks.UseAction()  IA:UpdateTempCursor('UseAction')  end    -- Possible ground targeting spell.


function IA:UpdateTempCursor(cmdName)
	local actives = self.activeCommands
	local TempCursor = GetCursorInfo() or SpellIsTargeting()
	if actives.TempCursor == TempCursor then  return  end

	actives.TempCursor = TempCursor
	if TempCursor then  self:SetActionModeTemp(nil)  end    -- There is a more recent event now.
	self:UpdateMouselook(not TempCursor, cmdName)
end


function IA:CommandHook(cmdName, pressed, event)
	-- Update SpellIsTargeting after pressing or releasing LeftButton.
	if cmdName == 'CameraOrSelectOrMove' then  self.activeCommands.TempCursor = GetCursorInfo() or SpellIsTargeting()  end

	self:ProcessCommand(cmdName, pressed)
	-- if self.commandsHooked[cmdName]=='MouseTurn' then  possibleTransition = pressed  else  possibleTransition = not pressed  end
	-- Do MouselookStart/Stop as necessary
  self:UpdateMouselook(nil, event)
end


function IA:PLAYER_STARTED_MOVING(event)
	Log.Event(event)
end

function IA:PLAYER_STOPPED_MOVING(event)
	Log.Event(event)
	if self.activeCommands.AutoRun then
		IA:SetCommandState('AutoRun', false)
		Log.Anomaly("  IA:PLAYER_STOPPED_MOVING():  Disabled activeCommands."..colors.AutoRun.."AutoRun|r, state would have been inverted, and MoveAndSteer rebinding to TurnWithoutAction stuck.")
		-- UpdateMouselook() does not depend on AutoRun, therefore not called.
	end
end


-------------
-- Hooking --
-------------

local function HookCommandPrefixed(IA, cmdName, funcStart, funcStop)
	hooksecurefunc(funcStart, function ()  IA:CommandHook(cmdName, true,  funcStart )  end)
	hooksecurefunc(funcStop , function ()  IA:CommandHook(cmdName, false, funcStop  )  end)
end


function IA:HookCommands()
	Log.Init('IA - HookCommands()')
	
	for  cmdName,group  in  pairs(self.commandsHooked)  do
		local stopFunc = CommandStopFunc[cmdName]
		if stopFunc ~= false then  HookCommandPrefixed(self, cmdName, cmdName..'Start', stopFunc or cmdName..'Stop')  end
	end
	self.hooked = nil		-- free up, not used until /reload
	
	for  funcName,hookFunc  in  pairs(UniqueHooks)  do
		if  G[funcName]  then
			hooksecurefunc(funcName, hookFunc)
		end
	end

	hooksecurefunc('MouselookStart', IA.NotifyMouselookUsage)
	
	-- Release this function, ensure it's not called again.
	self.HookCommands = nil
end


function IA.NotifyMouselookUsage()
	if  IA.notifiedMouselook  or  IA.db.global.dontNotify  then  return  end
	IA.notifiedMouselook = true
	local callerFrame = 3  -- 0:debugstack, 1:this function, 2:MouselookStart (the hooked one), 3:caller (or another hook added later)
	local callerStack = G.debugstack(callerFrame,3,0)  -- read 3 frames to allow for tailcails (no filepath in those)
	local callerPath = callerStack and callerStack:match("^(.-): ")
	local msg = IA.colors.yellow.."ImmersiveAction|r:  another addon also uses MouselookStart(). If you experience unexpected mouse beaviour then consider disabling one addon. The call seems to originate from:  "..callerPath
	print(msg)
	LibShared.softassert(false, msg)
end



---------------------------------
-- Bindings.xml implementation --
---------------------------------

function IA:ToggleActionMode(toState)
	-- Invert current state if called without argument.
	-- if toState==nil then  toState = not IsMouselooking()  end
	-- local toState = not self:ExpectedMouselook()
	-- local toState = not self.activeCommands.ActionMode
	local toState = not self.lastMouselook
	
	self:SetActionMode(toState, true)
	self:UpdateMouselook(toState, 'ToggleActionMode')
end


function IA:InvertMouselook(pressed)
	-- MouseTurn in CursorMode / ReleaseCursor in ActionMode.
	local invertTo
	if pressed then
		invertTo = not self.lastMouselook
		self.activeCommands.InvertMouselookTo = invertTo
	else
		invertTo = self.activeCommands.InvertMouselookTo
		self.activeCommands.InvertMouselookTo = nil
	end
	if invertTo then
		self:SetCommandState('TurnWithoutInteract', pressed)
		self:UpdateMouselook(pressed, 'TurnWithoutInteract')
	else
		self:SetCommandState('ReleaseCursor', pressed)
		self:UpdateMouselook(not pressed, 'ReleaseCursor')
	end
end

function IA:TurnWithoutInteract(pressed)
	-- Like TurnOrAction (RightButton), without accidental interacting / pull / target change when released.
	self:SetCommandState('TurnWithoutInteract', pressed)
	self:UpdateMouselook(pressed, 'TurnWithoutInteract')
end

function IA:ReleaseCursor(pressed)
	-- RightButton in ActionMode.
	self:SetCommandState('ReleaseCursor', pressed)
	self:UpdateMouselook(not pressed, 'ReleaseCursor')
end

--[[
function IA:TurnOrActionHijack(pressed)
	-- TurnOrAction was pressed, then hijacked just before being released to avoid Interacting. Act as if TurnOrAction was released.
	self:SetCommandState('TurnOrAction', pressed)
	self:UpdateMouselook(nil, 'TurnOrActionHijack')
end
--]]




--------------------
-- Event handlers --
--------------------

function IA:RegisterCommandEvents(enable)
	if enable ~= false then
		self:RegisterEvent('MODIFIER_STATE_CHANGED')
		self:RegisterEvent('CURRENT_SPELL_CAST_CHANGED')
		self:RegisterEvent('CURSOR_UPDATE')
		self:RegisterEvent('PET_BAR_UPDATE', 'CURSOR_UPDATE')
		-- self:RegisterEvent('PET_BAR_UPDATE')
		-- self:RegisterEvent('ACTIONBAR_UPDATE_STATE')
		self:RegisterEvent('PLAYER_STARTED_MOVING')
		self:RegisterEvent('PLAYER_STOPPED_MOVING')
	else
		self:UnregisterEvent('MODIFIER_STATE_CHANGED')
		self:UnregisterEvent('CURRENT_SPELL_CAST_CHANGED')
		self:UnregisterEvent('CURSOR_UPDATE')
		self:UnregisterEvent('PET_BAR_UPDATE')
		-- self:UnregisterEvent('ACTIONBAR_UPDATE_STATE')
		self:UnregisterEvent('PLAYER_STARTED_MOVING')
		self:UnregisterEvent('PLAYER_STOPPED_MOVING')
	end
end


local IsModifierPressed = LibShared.Require.IsModifierPressed


function IA:MODIFIER_STATE_CHANGED(event)
	local actives = self.activeCommands
	local modifiers = self.db.profile.modifiers
	local IsEnableModPressed  = IsModifierPressed[ modifiers.enableModifier ]
	local IsDisableModPressed = IsModifierPressed[ modifiers.disableModifier ]

	local enableModPressed  = IsEnableModPressed  and IsEnableModPressed ()
	local disableModPressed = IsDisableModPressed and IsDisableModPressed()

	-- Both pressed in order mod1 + mod2 will keep the state of mod1 and ignore mod2. In short: do nothing when mod2 is pressed.
	if enableModPressed and disableModPressed then  return  end

	-- No change?
	if actives.enableModPressed == enableModPressed
	and actives.disableModPressed == disableModPressed
	then  return  end

	actives.enableModPressed = enableModPressed
	actives.disableModPressed = disableModPressed
	self:UpdateMouselook(nil, 'Modifier')
end




function IA:CURSOR_UPDATE(event, ...)
	--[[ CURSOR_UPDATE sent when
	1. cursor is shown (as hand) after being hidden for CameraOrSelectOrMove, TurnOrAction, MoveAndSteer, Mouselook
	2. after/before CURRENT_SPELL_CAST_CHANGED
	3. before UPDATE_MOUSEOVER_UNIT:  cursor changes over actionable object to  bubble (gossip) / sword (enemy) / dragon (flightmaster) / mail (mailbox) / satchel (vendor,bank,auction) / hearthstone (innkeeper) / what else?
	-- event is not sent twice when moving over an actionable object:  hidden -> show hand cursor -> action cursor
	-- event is NOT sent when hiding cursor
	--]]
	Log.Event(event, '  -> CursorPickup=' .. IA.colorBoolStr(CursorHasItem(), false) .. '  SpellIsTargeting=' .. IA.colorBoolStr(SpellIsTargeting(), false))
	self:UpdateTempCursor(event)
end


IA.CURRENT_SPELL_CAST_CHANGED = IA.UpdateTempCursor


--[[
-- Events when ranged spell targeting starts:
	--CURSOR_UPDATE
	--CURRENT_SPELL_CAST_CHANGED
	--CURSOR_UPDATE
	--ACTIONBAR_UPDATE_STATE
	-- + CURSOR_UPDATE
	-- + CURSOR_UPDATE
	
-- Events when ranged spell targeting ends:
	--UNIT_SPELL_CAST_FAILED_QUIET
	--UNIT_SPELL_CAST_FAILED_QUIET
	--CURSOR_UPDATE
	--CURRENT_SPELL_CAST_CHANGED
	--ACTIONBAR_UPDATE_STATE
--]]

function IA:PET_BAR_UPDATE(event)
	Log.Event(event, '  -> CursorPickup=' .. IA.colorBoolStr(CursorHasItem(), false) .. '  SpellIsTargeting=' .. IA.colorBoolStr(SpellIsTargeting(), false))
end

--[[ No need for these to my best knowledge. CURSOR_UPDATE handles it.
function IA:ACTIONBAR_UPDATE_STATE(event)
	if  self.activeCommands.CursorObjectOrSpellTargeting  then
		Log.Event(event, '  -> ResetCursor()')
		ResetCursor()
		-- Triggers CURSOR_UPDATE, that will do self:UpdateMouselook(not cursorAction, event)
	end
end
--]]



