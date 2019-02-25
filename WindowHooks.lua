local _G, ADDON_NAME, _ADDON = _G, ...
local IA = _G.ImmersiveAction or {}  ;  _G.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log

assert(_ADDON.WindowList, "Include WindowList.lua before WindowHooks.lua")
local getSubField = assert(_ADDON.getSubField, "getSubField() missing from WindowList.lua")
local tDeleteItem = _G.tDeleteItem  -- from FrameXML/Util.lua
local colors = IA.colors

IA.WindowsOnScreen = {}
IA.HookedFrames = {}
IA.FramesToHook = nil
local FramesToHookMap = {}

-- Monitor windows/frames that need the mousecursor.
-- If one of these frames show up Mouselook is stopped as soon as you release any movement/mouse buttons.
-- That means if some mildly important message pops up in the heat of the battle
-- you don't loose mouse control over your movement direction until you actually stop moving.
-- AutoRun works as usual, so you can use the mousecursor while you are flying/swimming/trampling over the meadow.
--[[
-- List visible frames releasing mouse:
/dump ImmersiveAction.WindowsOnScreen
-- List frames not hooked / missing:
/dump ImmersiveAction.FramesToHook
--]]



local indexOf = LibShared.Require.indexOf
local removeFirst = assert(_G.tDeleteItem, "Bliz deleted FrameXML/Util.lua # function tDeleteItem()")

local function setInsertLast(item)
	if  indexOf(self, item)  then  return false  end
	table.insert(self, item)
	return true
end
--[[
local function setReInsertLast(item)
	local replaced = removeFirst(self, item)
	table.insert(self, item)
	return replaced
end
--]]


-------------------------
-- OnShow OnHide hooks --
-------------------------

local function FrameOnShow(frame)
	Log.Frame('  CM_FrameOnShow('.. colors.show .. frame:GetName() ..'|r)')
	-- if already visible do nothing
	if  not setInsertLast(IA.WindowsOnScreen, frame)  then  return  end

	self.commandState.ActionModeRecent = nil    -- There is a more recent event now.
	IA:UpdateMouselook(false, 'FrameOnShow')
end


local function FrameOnHide(frame)
	Log.Frame('  CM_FrameOnHide('.. colors.hide .. frame:GetName() ..'|r)')
	local removed= removeFirst(IA.WindowsOnScreen, frame)
	if  not removed  then  return  end
	
	IA:UpdateMouselook(true, 'FrameOnHide')
end



-----------------------------------
-- Hook OnShow OnHide on a frame --
-----------------------------------

function  IA:HookFrame(frameName)
	local frame
	-- _G[frameName] and getglobal(frameName) does not work for child frames like "MovieFrame.CloseDialog"
	if type(frameName)=='string' then  frame = _G[frameName]  or  getSubField(_G, frameName)
	else  frame = frameName ; frameName = frame:GetName() or frame  end

	if  not frame  or  self.HookedFrames[frameName]  then  return frame  end

	self.HookedFrames[frameName] = frame
	
	frame:HookScript('OnShow', FrameOnShow)
	if  not frame:GetScript('OnShow')  then  frame:SetScript('OnShow', FrameOnShow)  end
	frame:HookScript('OnHide', FrameOnHide)
	if  not frame:GetScript('OnHide')  then  frame:SetScript('OnHide', FrameOnHide)  end
	
	if  frame:IsShown()  then
		Log.Frame('  CM:HookUpFrames():  '.. colors.show .. frame:GetName() ..'|r is already visible')
		setInsertLast(IA.WindowsOnScreen, frame)
	end
	
	return frame
end



---------------------
-- Hook all frames --
---------------------

function  IA:HookUpFrames()
	Log.Init('ImmersiveAction:HookUpFrames()')

	if _ADDON.WindowList and not self.FramesToHook then
		self.FramesToHook = _ADDON.WindowList
    -- garbagecollect
		_ADDON.WindowList = nil
	end

	-- Monitor UIPanelWindows{}:  main bliz windows.
	for  frameName,frame  in  pairs(_G.UIPanelWindows)  do
		self:HookFrame(frame)
	end

	-- Monitor UISpecialFrames[]:  some windows added by bliz FrameXML and also addons. No need to list them by name.
	for  idx, frameName  in  ipairs(_G.UISpecialFrames)  do
		self:HookFrame(frameName)
	end

	-- UIChildWindows[]:  parents should be monitored.
	-- UIMenus[]:  ignored. If a menu opens, the cursor was already visible.

	local FramesToHookNew = {}
	wipe(FramesToHookMap)
	for  idx, frameName  in  ipairs(self.FramesToHook)  do
		-- if  self.HookedFrames[frameName]  then  print('ImmersiveAction:HookUpFrames(): frame hooked again:  ' .. frameName)  end
		local frame= self:HookFrame(frameName)
		if  not frame  then	
			-- missing frames stored for a next round
			FramesToHookMap[frameName] = frameName
			FramesToHookNew[#FramesToHookNew+1]= frameName
		end
	end

	self.FramesToHook= FramesToHookNew
	if  0 < #FramesToHookNew  and  self:IsLogging('Init')  and  self.logging.Anomaly  then
		--local missingList= table.concat(FramesToHookNew, ', ')		-- this can be long
		Log.Init('  CM:HookUpFrames():  missing '.. #FramesToHookNew ..' frames.  List them by entering   /dump ImmersiveAction.FramesToHook')
	end
end



---------------------------
-- Hook creating a frame --
---------------------------

hooksecurefunc('CreateFrame', function(frameType, frameName, ...)
	if  not FramesToHookMap[frameName]  then  return  end
	
	local frame = IA:HookFrame(frameName)
  if  frame  then
		FramesToHookMap[frameName] = nil
		tDeleteItem(IA.FramesToHook, frameName)
	end
end)




------------------------------
-- Listen for quest events. These fire even if Immersion addon hides the QuestFrame.
------------------------------

function IA:QUEST_PROGRESS(event)
	-- Event QUEST_PROGRESS received as the quest frame is shown when talking to an npc
	Log.Event(colors.show .. event .. colors.restore)
	setInsertLast(self.WindowsOnScreen, 'QUEST_PROGRESS')
	self.commandState.ActionModeRecent = nil    -- There is a more recent event now.
	self:UpdateMouselook(false, event)
end

function IA:QUEST_FINISHED(event)
	-- Event QUEST_FINISHED received as the quest frame is closed after talking to an npc
	Log.Event(colors.hide .. event .. colors.restore)
	removeFirst(self.WindowsOnScreen, 'QUEST_PROGRESS')
	self:UpdateMouselook(true, event)
end




------------------------------
-- Return an onscreen frame --
------------------------------

function IA:CheckForFramesOnScreen()
	return  self.WindowsOnScreen[1]
end


