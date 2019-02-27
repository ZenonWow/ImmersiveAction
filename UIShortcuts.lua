local GL, ADDON_NAME, ADDON = _G, ...


------------------------------------------
-- UIShortcuts bindings
------------------------------------------
BINDING_HEADER_UIShortcuts        = "UI Shortcuts - usability keybindings"

local UIShortcuts = GL.UIShortcuts or {}
GL.UIShortcuts = UIShortcuts

-- Bindings locales

-- See who's following: Look back while pushed, look forward when released.
BINDING_NAME_LookBackWhilePushed  = "Look back *while* pushed"
BINDING_NAME_LookLeft             = "Look left"
BINDING_NAME_LookRight            = "Look right"

-- Focus, Target selection
UIShortcuts.FocusMouseoverBinding = 'CLICK FocusMouseoverButton'    -- Name must be the same as in Bindings.xml.
GL['BINDING_NAME_'..UIShortcuts.FocusMouseoverBinding] = "Focus Mouseover"
UIShortcuts.ClearTargetBinding    = 'CLICK ClearTargetButton'       -- Name must be the same as in Bindings.xml.
GL['BINDING_NAME_'..UIShortcuts.ClearTargetBinding] = "Clear Target"

-- Eject a passenger. One at a time.
BINDING_NAME_EjectPassenger       = "Eject a passenger"

-- Open GameMenu without clearing target or closing every frame on screen.
BINDING_NAME_ToggleGameMenuOnly   = "Toggle Game Menu ONLY"
-- Open macro editor.
BINDING_NAME_ToggleMacroFrame     = "Toggle Macros frame"
-- Show/hide loot history frame.
BINDING_NAME_ToggleLootHistory    = "Toggle Loot History (rolls)"
--[[
-- "Go directly to Equipment Manager in Character Frame"
BINDING_NAME_TOGGLECHARACTEREQUIPMENT = "Toggle Equipment Manager"
-- "Almost the same as builtin Toggle Talents that actually opens Specializations: it does so even if last time you opened the Talents Tab"
BINDING_NAME_TOGGLESPECIALIZATION     = "Toggle Talent Specializations"
-- "Open the actual Talents Tab on the Talent Frame"
BINDING_NAME_TOGGLETALENTSTAB         = "Toggle Talents Tab"
--]]



------------------------------------------
-- UIShortcuts implemented
------------------------------------------

-- Clear Target
UIShortcuts.ClearTargetButton     = LibShared.Require.CreateMacroButton('ClearTargetButton', '/cleartarget')

-- Focus Mouseover
UIShortcuts.FocusMouseoverButton  = LibShared.Require.CreateMacroButton('FocusMouseoverButton', '/focus mouseover')
-- UIShortcuts.FocusMouseoverButton:SetAttribute('type', 'focus')
-- UIShortcuts.FocusMouseoverButton:SetAttribute('focus', 'mouseover')




-- Open the game menu without deselecting the target or closing frames like the map.
local  loud = nil
UIShortcuts.ToggleGameMenuOnly = UIShortcuts.ToggleGameMenuOnly  or  function()
	if  GameMenuFrame:IsShown()  then
		if loud then  PlaySound("igMainMenuQuit")  end
		print("HideUIPanel(GameMenuFrame)")
		HideUIPanel(GameMenuFrame)
	else
		if loud then  PlaySound("igMainMenuOpen")  end
		print("ShowUIPanel(GameMenuFrame)")
		ShowUIPanel(GameMenuFrame)
	end
end


UIShortcuts.ToggleMacroFrame = UIShortcuts.ToggleMacroFrame  or  function()
	--[[ Source:
	SlashCmdList.MACRO()    -- FrameXML/ChatFrame.lua
	ShowMacroFrame()        -- FrameXML/UIParent.lua
	--]]
	if  not MacroFrame  then  MacroFrame_LoadUI()  end
	ToggleFrame(MacroFrame)  -- Uses secure code if necessary.
end




--[[
-- Shift-Ctrl-X, Shift-Ctrl-Del:  Eject a passenger.
-- /run if IsControlKeyDown() then if CursorHasItem() then DeleteCursorItem() else EjectPassengerFromSeat(1);EjectPassengerFromSeat(2) end end
--]]
UIShortcuts.EjectPassenger = UIShortcuts.EjectPassenger  or  function()
	local seatIdx
	for  i = 1, UnitVehicleSeatCount('player')  do
		if  CanEjectPassengerFromSeat(i)  then
			local _, name, _, _, _ = UnitVehicleSeatInfo('player', seatIdx)
			print('Eject passenger '.. seatIdx ..': ' .. name)
			EjectPassengerFromSeat(seatIdx)
			break
		end
	end

	if not seatIdx then  print('No passengers to eject.')  end
end


