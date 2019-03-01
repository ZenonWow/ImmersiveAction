--[[
	-- TurnOrAction inverts the previous Mouselook state (the state before it was pressed).
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






function WorldClickHandler:InitSecureHandler()
	local handler = self    -- For clarity.
	-- Init "global" variables in secure environment.
	-- handler:SetAttribute('_set', " local name,value=... ; _G[name] = value ")

	-- handler.MouselookStop = IA.MouselookStop
	-- handler:Execute(WorldClickHandler.InitSnippet)
	-- handler.Env = G.GetManagedEnvironment(handler)

	-- handler:WrapScript(WorldFrame, 'OnMouseDown', prePressBody, nil)
	-- handler:WrapScript(WorldFrame, 'OnMouseUp'  , preReleaseBody, postReleaseBody)
	-- Same with less calls:
	-- SecureHandlerWrapScript(WorldFrame, 'OnMouseDown', handler, WorldFrame_OnMouseDown_PreSnippet, nil)
	-- SecureHandlerWrapScript(WorldFrame, 'OnMouseUp'  , handler, WorldFrame_OnMouseUp_PreSnippet, WorldFrame_OnMouseUp_PostSnippet)

	-- WrapScript(WorldFrame, 'OnMouseDown', handler, WorldFrame_OnMouseDown_PreSnippet, nil)
	-- WrapScript(WorldFrame, 'OnMouseUp', handler, WorldFrame_OnMouseUp_PreSnippet, WorldFrame_OnMouseUp_PostSnippet)

	-- SecureHandlerWrapScript(WorldFrame, 'OnClick', handler, WorldFrame_OnClick_PreSnippet, WorldFrame_OnClick_PostSnippet)
	-- WorldFrame has no OnClick script... splendid.

	-- SecureHandlerWrapScript(WorldFrame, 'OnMouseWheel', handler, UIParent_OnMouseWheel_PreSnippet, UIParent_OnMouseWheel_PostSnippet)
	-- SecureHandlerWrapScript(UIParent, 'OnMouseWheel', handler, UIParent_OnMouseWheel_PreSnippet, UIParent_OnMouseWheel_PostSnippet)
	
	-- handler:UpdateDoubleClickInterval()
	handler:UpdateOverrideBindings()
end


function WorldClickHandler:DisableHandler()
	-- self:UnwrapScript(WorldFrame, 'OnMouseDown')
	-- self:UnwrapScript(WorldFrame, 'OnMouseUp')
	-- self:UnwrapScript(WorldFrame, 'OnMouseWheel')
	-- self:UnwrapScript(UIParent  , 'OnMouseWheel')
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
	self:Execute(" CameraBUTTON,TurnBUTTON = '"..(Camera or '').."','"..(Turn or '').."' ")
	self:Execute(" BUTTONs = newtable() ")
	self:Execute(" BUTTONs.CAMERAORSELECTORMOVE = '"..Camera.."' ")
	self:Execute(" BUTTONs.TURNORACTION = '"        ..Turn.."' ")
end




