local _G, ADDON_NAME, _ADDON = _G, ...
local IA = _G.ImmersiveAction or {}  ;  _G.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log


---------------------------
-- Log: print state transitions, commands, etc.
---------------------------

--[[
-- logging:
/run ImmersiveAction.logging.all= false
/run ImmersiveAction.logging.Anomaly= false
/run ImmersiveAction.logging.State= false
/run ImmersiveAction.logging.Update= true
/run ImmersiveAction.logging.Command= true
-- set to true or false  to override individual event settings
/run ImmersiveAction.logging.Event.all= false
-- individual events
/run ImmersiveAction.logging.Event.CURSOR_UPDATE= false
/run ImmersiveAction.logging.Event.PLAYER_TARGET_CHANGED= false
/run ImmersiveAction.logging.Event.PET_BAR_UPDATE= false
/run ImmersiveAction.logging.Event.ACTIONBAR_UPDATE_STATE= false
/run ImmersiveAction.logging.Event.QUEST_PROGRESS= false
/run ImmersiveAction.logging.Event.QUEST_FINISHED= false
--]]
IA.logging= {
	-- all= false,		-- set to false/true to override individual event settings.
	-- all= true,
	State= false,
	Update= false,
	Command= false,
	-- Anomaly= false,
	Anomaly= true,
	Init= false,
	Frame= false,
}
IA.logging.Event= {
	all= false,		-- set to false/true to override individual event settings.
	-- all= true,
	CURSOR_UPDATE= false,
	PLAYER_TARGET_CHANGED= true,
	-- PET_BAR_UPDATE= true,
	-- ACTIONBAR_UPDATE_STATE= false,
	QUEST_PROGRESS= true,
	QUEST_FINISHED= true,
}


local function makeLogFunc(Log, logging, categ)
	Log[categ] =  function(...)  if logging:_on(categ) then print(...) end  end
end
function IA.logging:_on(categ)
	return  self.all~=false  and  (self[categ] or self.all)
end

IA.logging.Event._on = IA.logging._on
function IA.logging:_onevent(event)
	return  self.all ~= false  and  self.Event  and  self.Event:_on(event)
end

makeLogFunc(Log, IA.logging, 'State')
makeLogFunc(Log, IA.logging, 'Update')
makeLogFunc(Log, IA.logging, 'Command')
makeLogFunc(Log, IA.logging, 'Anomaly')
makeLogFunc(Log, IA.logging, 'Init')
makeLogFunc(Log, IA.logging, 'Frame')

function Log.Event(event, extraMessage)
	if  IA.logging:_onevent(event)  then
		print(event ..':  cursor='.. (GetCursorInfo() or 'hand')
		..' CursorPickedUp()='.. IA.colorBoolStr(CursorPickedUp(),true)
		..' SpellIsTargeting()='.. IA.colorBoolStr(SpellIsTargeting(),true)
		.. (extraMessage or '') )
	end
end



--[[ Change colors used in logging
/run ImmersiveAction.colors['nil']= ImmersiveAction.colors.blue
/run ImmersiveAction.colors[false]= ImmersiveAction.colors.blue
/run ImmersiveAction.colors[true]= ImmersiveAction.colors.green

/run ImmersiveAction.colors.up = ImmersiveAction.colors.gray
--]]
local colors = {
		black			= "|cFF000000",
		white			= "|cFFffffff",
		gray			= "|cFFbeb9b5",
		blue			= "|cFF00b4ff",
		lightblue	= "|cFF96c0ff",
		purple		= "|cFFcc00ff",
		green			= "|cFF00ff00",
		green2		= "|cFF66ff00",
		lightgreen= "|cFF98fb98",
		darkred		= "|cFFc25b56",
		red				= "|cFFff0000",
		orange		= "|cFFff9900",
		yellow		= "|cFFffff00",
		parent		= "|cFFbeb9b5",
		error			= "|cFFff0000",
		ok				= "|cFF00ff00",
		restore		= "|r",
}
IA.colors = colors
colors['nil']			= colors.gray
colors[false]			= colors.gray
colors.up					= colors.gray
colors[true]			= colors.lightblue
colors.down				= colors.lightblue		--colors.purple
colors.missedup		= colors.orange
colors.show				= colors.lightblue
colors.hide				= colors.blue
colors.event			= colors.lightgreen
colors.ActionMode = colors.orange
colors.AutoRun    = colors.orange
colors.Mouselook  = colors.yellow

function IA.coloredKey(cmdName, pressed)
	local keystate = pressed and "DOWN" or "UP"
	return colors[pressed]..cmdName.." "..keystate.."|r"
end

function IA.colorBoolStr(value, withColor)
	local boolStr=  value == true and 'ON'  or  value == false and 'OFF'  or  tostring(value)
	if  withColor == true  then  withColor= colors[value == nil  and  'nil'  or  value]  end
	return  withColor  and  withColor .. boolStr .. colors.restore  or  boolStr
end
local colorBoolStr = IA.colorBoolStr



