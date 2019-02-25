----------------------
-- Shared functions
----------------------

-----------------------------
--- LibShared.BasicKeyToButton['BUTTON1'] == LeftButton
-- Map keybinding identifiers (tokens)  'BUTTON*'  to  '*Button'  - OnMouseDown/OnMouseUp/OnClick (frame script) button identifiers/tokens.
--
LibShared.Define.BasicKeyToButton = {
	-- Necessary special cases:
	BUTTON1 = 'LeftButton',
	BUTTON2 = 'RightButton',
	BUTTON3 = 'MiddleButton',
	-- Common:
	BUTTON4 = 'Button4',
	BUTTON5 = 'Button5',
	-- 8 fields are preallocated, these are free in terms of memory:
	-- BUTTON6 = 'Button6',
	-- BUTTON7 = 'Button7',
	-- BUTTON8 = 'Button8',
}
local BasicKeyToButton = LibShared.BasicKeyToButton


--- LibShared.MapKeyToButton('BUTTON1') == LeftButton
-- Map keybinding identifiers (tokens) to OnMouseDown/Up, OnClick - Frame Script - button identifiers/tokens.
-- No mapping for MOUSEWHEELUP, MOUSEWHEELDOWN.
-- Returns the applied modifiers in an array as second return value.
-- @return  '...Button',  { modifiers } (list of 'ALT','CTRL','SHIFT')
-- If this is not a Button then return the split modifiers and key in an array as second return value.
-- @return  nil,  { modifiers, 'KEY' }
-- @see BUTTON_LOOKUP_TABLE[] in FrameXML/SecureTemplates.lua
--
LibShared.Define.MapKeyToButton = function(self, key)
	-- Fast path for BUTTON1 - BUTTON5 without modifiers.
	local btn = BasicKeyToButton[key]
	if  btn or not key  then  return btn,nil  end

	-- Split off modifiers.
	local mods = { strsplit('-', key) }
	local last = mods[#mods]
	if #mods==1 then  mods = nil  end
	-- Only map through BasicKeyToButton _again_ if there were mods split off.
	local btn =  mods  and  BasicKeyToButton[last]
	if  not btn  and  last:sub(1,6)=='BUTTON'  then  btn = 'Button'..last:sub(7)  end
	-- If found the button then remove from the end of the mods list.
	if  btn and mods  then  mods[#mods] = nil  end
	return btn,mods
end
local MapKeyToButton = LibShared.MapKeyToButton


local function GetBindingButtonAndKey(command)
	-- Default UI has 2 columns for 2 keys, but more is saved in keybinding profile.
	local key1,key2,key3 = GetBindingKey(command)
	local btn1,mods1 = MapKeyToButton(key1)
	if btn1 and not mods1 then  return btn1,key1  end
	local btn2,mods2 = MapKeyToButton(key2)
	if btn2 and not mods2 then  return btn2,key2  end
	local btn3,mods3 = MapKeyToButton(key3)
	if btn3 and not mods3 then  return btn3,key3  end
	-- If all has mods then return the first.
	return btn1,key1
end






Capturing commands that should do Mouselooking. Doing so in the WorldClickHandler secure handler. Not good place for it.
--
	-- Mouselooking = newtable()  -- In UpdateOverrideBindings().
	local keys = {}
	for i,command in ipairs(WorldClickHandler.MouselookingCommands) do

	keys[1] = "local List = newtable('" .. keys[1]
	keys[#keys] = keys[#keys] .. "')"
	local mlookingKeysSnippet = strjoin("','", keys)
	handler:Execute(mlookingKeysSnippet)
	
	local ListToMapSnippet = " Mouselooking=newtable() ; for i,key in ipairs(List) do  Mouselooking[key]=1  end "
	handler:Execute(ListToMapSnippet)
end



