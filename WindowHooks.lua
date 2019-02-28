local GL, ADDON_NAME, ADDON = _G, ...
local IA = GL.ImmersiveAction or {}  ;  GL.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log

assert(ADDON.WindowList, "Include WindowList.lua before WindowHooks.lua")
local getSubField = assert(ADDON.getSubField, "getSubField() missing from WindowList.lua")
local tDeleteItem = GL.tDeleteItem  -- from FrameXML/Util.lua
local colors = IA.colors

local DB

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
local removeFirst = assert(GL.tDeleteItem, "Bliz deleted FrameXML/Util.lua # function tDeleteItem()")

local function setInsertLast(t, item)
	if  indexOf(t, item)  then  return false  end
	table.insert(t, item)
	return true
end
--[[
local function setReInsertLast(t, item)
	local replaced = removeFirst(t, item)
	table.insert(t, item)
	return replaced
end
--]]


-------------------------
-- OnShow OnHide hooks --
-------------------------

function IA.FrameOnShow(frame)
	Log.Frame('  IA.FrameOnShow('.. colors.show .. frame:GetName() ..'|r)')
	-- if already visible do nothing
	if  not setInsertLast(IA.WindowsOnScreen, frame)  then  return  end

	IA.commandState.ActionModeRecent = nil    -- There is a more recent event now.
	IA:UpdateMouselook(false, 'FrameOnShow')
end


function IA.FrameOnHide(frame)
	Log.Frame('  IA.FrameOnHide('.. colors.hide .. frame:GetName() ..'|r)')
	local removed= removeFirst(IA.WindowsOnScreen, frame)
	if  not removed  then  return  end
	
	IA:UpdateMouselook(true, 'FrameOnHide')
end



-----------------------------------
-- Hook OnShow OnHide on a frame --
-----------------------------------

-- Take from a proper frame.
local HookScript = IA.UserBindings.HookScript
local STEP = 25


local function DBAdd(listName, frameName)
	local was = DB[listName]
	local len = #was + #frameName
	local pad = STEP - len % STEP
	local nl = ""
	if 4*STEP < len % (5*STEP) then
		pad = pad-1
		nl = "\n"
	end
	local padS = string.rep(" ", pad)
	DB[listName] = was .. frameName .. padS .. nl
end


function  IA:HookFrame(frameName, frame)
	-- GL[frameName] and getglobal(frameName) does not work for child frames like "MovieFrame.CloseDialog"
	if not frame and type(frameName)=='string' then  frame = GL[frameName]  or  getSubField(GL, frameName)  end
	if not frame  or  self.HookedFrames[frameName] then  return frame  end
	-- if not frame.GetName then  print("No GetName():", frameName, frame, type(frame))  end
	if not frame.GetName then  DBAdd('NoGetName', frameName)  end

	self.HookedFrames[frameName] = frame
	
	if not frame.HookScript then
		-- print("NonHook:  ", frameName)
		DBAdd('NonHook', frameName)
		-- Stop annoying.
		-- return frame
	end
	
	local ok1, err1 = pcall(HookScript, frame, 'OnShow', IA.FrameOnShow)
	if not ok1 then DB.ErrFrames[frameName] = err1 end
	-- if  not frame:GetScript('OnShow')  then  frame:SetScript('OnShow', IA.FrameOnShow)  end
	local ok2, err2 = pcall(HookScript, frame, 'OnHide', IA.FrameOnHide)
	if ok1 and not ok2 then DB.ErrFrames[frameName] = err2 end
	-- if  not frame:GetScript('OnHide')  then  frame:SetScript('OnHide', IA.FrameOnHide)  end
	if ok1 and ok2
	then  DBAdd('GoodFrames', frameName)
	else  DBAdd('ErrHook', frameName)
	end
	
	if  frame.IsShown and frame:IsShown()  then
		Log.Frame('  IA:HookUpFrames():  '.. colors.show .. frameName ..'|r is already visible')
		setInsertLast(IA.WindowsOnScreen, frame)
	end
	
	return frame
end



---------------------
-- Hook all frames --
---------------------

local function InitDB()
	if DB then  return  end
	DB = GL.ImmersiveActionDB or {}  ;  GL.ImmersiveActionDB = DB
	DB.NoGetName = ""
	DB.NonHook = ""
	DB.ErrHook = ""
	DB.ErrFrames = {}
	DB.GoodFrames = ""
	DB.MissFrames = ""
end

function  IA:HookUpFrames()
	Log.Init('ImmersiveAction:HookUpFrames()')
	InitDB()

	if ADDON.WindowList and not self.FramesToHook then
		self.FramesToHook = ADDON.WindowList
    -- garbagecollect
		ADDON.WindowList = nil
	end

	-- Monitor UIPanelWindows{}:  main bliz windows.
	for  frameName,frame  in  pairs(GL.UIPanelWindows)  do
		self:HookFrame(frameName, frame)
	end

	-- Monitor UISpecialFrames[]:  some windows added by bliz FrameXML and also addons. No need to list them by name.
	for  idx, frameName  in  ipairs(GL.UISpecialFrames)  do
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
	if  0 < #FramesToHookNew  and  self.logging._on('Init')  and  self.logging.Anomaly  then
		--local missingList= table.concat(FramesToHookNew, ', ')		-- this can be long
		Log.Init('  IA:HookUpFrames():  missing '.. #FramesToHookNew ..' frames.  List them by entering   /dump ImmersiveAction.FramesToHook')
	end
	
	DB.MissFrames = ""
	for i,frameName in ipairs(FramesToHookNew) do
		DBAdd('MissFrames', frameName)
	end
end



---------------------------
-- Hook creating a frame --
---------------------------

hooksecurefunc('CreateFrame', function(frameType, frameName, ...)
	if  not FramesToHookMap[frameName]  then  return  end
	
	print("IA.hook.CreateFrame()", frameName)
	local frame = IA:HookFrame(frameName)
  if frame then
		FramesToHookMap[frameName] = nil
		tDeleteItem(IA.FramesToHook, frameName)
	end
end)




------------------------------
-- Listen for quest events. These fire even if Immersion addon hides the QuestFrame.
------------------------------

function IA:RegisterWindowEvents(enable)
	if enable ~= false then
		self:RegisterEvent('QUEST_PROGRESS')
		self:RegisterEvent('QUEST_FINISHED')
	else
		self:UnregisterEvent('QUEST_PROGRESS')
		self:UnregisterEvent('QUEST_FINISHED')
	end
end


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

function IA:AnyFramesOnScreen()
	return  self.WindowsOnScreen[1]
end


