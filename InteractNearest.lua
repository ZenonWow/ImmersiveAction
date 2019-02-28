local G, ADDON_NAME, ADDON = _G, ...
local IA = G.ImmersiveAction or {}  ;  G.ImmersiveAction = IA
local Log = IA.Log or {}  ;  IA.Log = Log

local LibShared,CreateFrame,ipairs,GetBindingKey = LibShared,CreateFrame,ipairs,GetBindingKey


---------------------------------
-- TargetNearestAndInteractNpc aka. InteractNearest, InteractNearest, SmartTargeting
---------------------------------

local InCombatHandler = CreateFrame('Frame', nil, nil, 'SecureHandlerStateTemplate,SecureHandlerAttributeTemplate')
local InteractNearest = InCombatHandler
-- local InteractNearest = CreateFrame('Frame')
IA.InteractNearest = InteractNearest
LibShared.SetScript.OnEvent(InteractNearest)

InteractNearest:Hide()
InteractNearest.InCombatHandler = InCombatHandler
-- InteractNearest.TargetEnemiesToo = 'TARGETNEAREST'
InteractNearest.TargetCommand = 'TARGETNEARESTFRIEND'
InteractNearest.InteractRange = 3    -- yards
InteractNearest.CheckInterval = 0.3  -- seconds


--- INTERACTTARGET --> TARGETNEARESTFRIEND / INTERACTTARGET depending on range.
-- One-key interact like in all modern/sane RPGs.
InteractNearest.Overrides = {}
InteractNearest.Overrides.INTERACTTARGET  = true
InteractNearest.Overrides.INTERACTNEAREST = true




--[[ Dec 7, 2017 by justice7ca
"Smart Targeting" to replace the default left click, or to be remapped with a keybind.
Essentially it will:
- No Target Selected
	- Scan for Enemy Target
		- No Enemy Target Found, Target Friendly
- Enemy Targeted
	- Scan for Target Enemy (click for new target)
- Friendly Targeted
	- If Friendly Target is within interact range, interact with target, otherwise Select Enemy Player Scan / Select Friendly if none found
The purpose of this is to allow left click to be used for multiple purposes while in ActionMode.
--]]

--[[ Dec 10, 2017 by justice7ca
 I actually ended up handling this slightly differently in 1.2.0.
 Left click selects friendly by default, if you're within range, it will change to interact for you.
 If you're out of range, it's back to select friendly.
 Essentially allowing you to Mouse1 your way to victory while questing / talking to NPC's.
--]]



---------------------------------
-- SecureHandlerStateTemplate for a minimal in-combat functionality
---------------------------------

-- Set all keys to a best-effort guess by the StateHandler.
--
-- globals:  lastBinding, TargetCommand, DynamicKeys
--- OverrideBindingInCombat(self, stateid, newstate)
InCombatHandler.OverrideBindingInCombat = [===[
	if newstate=='ignore' then  return  end
	-- if not PlayerInCombat() then  return  end    -- Done with 'ignore' now.

	if newstate == lastBinding
	then  print("OverrideBindingInCombat():  newstate == lastBinding ==", newstate)
	else  print("OverrideBindingInCombat():  lastBinding was=", lastBinding, "newstate=", newstate)
  end
	lastBinding = newstate
	local command =  newstate~=''  and  newstate  or  nil

	for key,original in pairs(DynamicKeys) do
		self:SetBinding(true, key, command)    -- true: priority over UserBindings (where user selected INTERACTNEAREST)
	end
]===]


local rtablepairs = G.rtable.pairs

-- Pair of OverrideBindingInCombat in insecure (out-of-combat) context.
function InCombatHandler:OverrideBindingOutOfCombat(command)
	local DynamicKeys = self.Env.DynamicKeys

	-- Iterate the same, restricted table as the secure version. Reading is allowed.
	for key,original in rtablepairs(DynamicKeys) do
		self:SetBinding(true, key, command)    -- true: priority over UserBindings (where user selected INTERACTNEAREST)
	end
end




--[[
Test macro conditionals:
[harm][dead] INTERACTTARGET ; [noharm][nodead] INTERACTTARGET ; TARGETNEARESTFRIEND
In combat:
-- target,interact,target,interact,..  --  Cannot trigger on keypress in secure context to switch the binding.
-- Auto-bind with this StateHandler macro:
[harm][dead] INTERACTTARGET ; [noharm][nodead] INTERACTTARGET ; [combat] TARGETLASTHOSTILE ; TARGETNEAREST
-- Out-of-combat:  check distance, override with TARGETNEAREST if far. OnUpdate and on target change.
-- StateHandler will override on next target change, then the distance logic triggers and overrides, if out-of-combat.

/dump SLASH_TARGET_LAST_ENEMY
/dump SLASH_TARGET_NEAREST_ENEMY
/dump SLASH_TARGET_NEAREST_FRIEND
/targetlastenemy

/console targetNearestDistance 10,000000
/targetenemy [noharm][dead]
/console targetNearestDistance 41.000000
--]]


function InCombatHandler:InitSecureHandler()
	 -- The StateDriver decides in combat what binding command to use.
	 -- Checking distance is prohibited intentionally in secure context.
	--[[
	-- [harm,dead]: dead enemy, possibly lootable ; [noharm,nodead]: friendly, possibly npc
	local NoCombatCondition = "[nocombat] ignore ; "
	local MouseOverCondition = "[@mouseover,harm,dead] [@mouseover,noharm,nodead] INTERACTMOUSEOVER ; "
	local TargetCondition = "[harm,dead] [noharm,nodead] INTERACTTARGET"
	--]]
	-- In combat it should focus only on looting. Are there any fights that require chatting with friendly npcs?
	-- Anyways in CursorMode the user can rightclick the friendly npc, while
	-- in ActionMode pressing the RightButton will show the cursor (invert Mouselook)
	-- which will interact when released, using the SuppressRightClick hack in reverse... splendid.
	local NoCombatCondition = "[nocombat] ignore ; "
	local MouseOverCondition = "[@mouseover,harm,dead] INTERACTMOUSEOVER ; "
	local TargetCondition = "[harm,dead] INTERACTTARGET"
	-- Note: INTERACTMOUSEOVER falls back to INTERACTTARGET if it can't interact, and
	-- will interact with any targeted unit, attacking if its enemy.
	-- In the heat of the battle this will seldom be noticed.

	local handler = self    -- For clarity.
	-- G.SecureStateDriverManager:RegisterEvent("UPDATE_MOUSEOVER_UNIT")  -- necessary?
	G.RegisterStateDriver(handler, 'INTERACTNEAREST', NoCombatCondition .. MouseOverCondition .. TargetCondition)

	handler:SetAttribute('_onstate-'..'INTERACTNEAREST', self.OverrideBindingInCombat)
	self.OverrideBindingInCombat = nil
	-- handler:SetAttribute('_onattributechanged', self.AttributeChangedSnippet)
	-- self.AttributeChangedSnippet = nil
	
	-- Create the "globals" available to the snippets in the protected environment.
	-- DynamicKeys (key->toCmd) restricted table:
	handler:Execute(" DynamicKeys = newtable() ")
	handler.Env = G.GetManagedEnvironment(handler)

	-- TargetCommand:  copy of InteractNearest.TargetCommand
	-- handler:SetAttribute('_setTargetCommand', " TargetCommand = ... ")
	-- handler:SetAttribute('_set',    " local name,value=... ; _G[name] = value ")
	-- handler:SetAttribute('_addKey', " local key,toCmd=... ; DynamicKeys[key] = toCmd ")
	self:SetTargetCommand(self.TargetCommand)

	self.InitSecureHandler = nil
end


function InteractNearest:SetTargetCommand(TargetCommand)
	self.TargetCommand = TargetCommand
	if InCombatLockdown() then  return  end

	local handler = self    -- For clarity.
	-- handler.Env.TargetCommand = self.TargetCommand
	-- handler:RunAttribute('_setTargetCommand', self.TargetCommand)
	-- handler:RunSnippet('_setTargetCommand', self.TargetCommand)
	handler:Execute(" TargetCommand = '"..self.TargetCommand.."' ")
end


function InteractNearest:SetTargetEnemiesToo(enable)
	self:SetTargetCommand( enable and 'TARGETNEAREST' or 'TARGETNEARESTFRIEND' )
end


-- Upload the managed keys from the insecure table to the secure (restricted) DynamicKeys table.
function InCombatHandler:UploadKeys(insecureKeys)
	local handler = self    -- For clarity.

	print("InCombatHandler:UploadKeys()")
	handler:Execute(" wipe(DynamicKeys) ")
	for key,fromCmd in pairs(insecureKeys) do
		-- handler:RunAttribute('_addKey', key, fromCmd)
		-- handler:RunSnippet('_addKey', key, fromCmd)
		-- RunSnippet() is not found on Earth, or in any code. Only "Iriel’s Field Guide to Secure Handlers" mentions it, but not how to set the snippets.
		-- handler:Execute(" local key,fromCmd=... ; DynamicKeys[key] = fromCmd ", key, fromCmd)
		handler:Execute(" DynamicKeys['"..key.."'] = '"..fromCmd.."' ")
	end
end


---------------------------------
-- InteractNearest periodic OnUpdate to check distance every 0.3 sec.
---------------------------------

InteractNearest.sinceLastCheck = 0

-- OnUpdate() runs if  ==  IA.InteractNearest:IsShown()  ==  IA.DynamicKeys and not InCombatLockdown()
function InteractNearest:OnUpdate(elapsed)
	-- Periodic update every frame (per 33ms at 30fps). Skip frames until CheckInterval passed.
	self.sinceLastCheck = self.sinceLastCheck + elapsed
	if  self.CheckInterval < self.sinceLastCheck  and  self.trackedUnit then
		self.sinceLastCheck = 0
		self:OverrideBindings()
	end
end

-- The insecure OnUpdate() runs only if the frame IsShown(), which
-- happens when tracking a unit out-of-combat.
-- In combat it's prohibited to change bindings anyway.
InteractNearest:SetScript('OnUpdate', InteractNearest.OnUpdate)


---------------------------------
-- Target change event(s)
---------------------------------

function InteractNearest:UPDATE_MOUSEOVER_UNIT(event, ...)
	Log.Event(event)
	-- Hovering a new mouseover will override the previous trackedUnit if it was 'target'.
	self:StartTackingUnit('mouseover')
end

function InteractNearest:PLAYER_TARGET_CHANGED(event, ...)
	Log.Event(event)
	-- Selecting a new target after finding a potential mouseover will override the trackedUnit.
	self:StartTackingUnit('target')
end



---------------------------------
-- Entering/leaving combat
---------------------------------

function InteractNearest:StartTacking()
	-- StartTackingUnit() calls OverrideBindings() if necessary.
	local unit =  self:StartTackingUnit('mouseover')  or  self:StartTackingUnit('target')
	self:Show()    -- Request OnUpdate() calls.
end


function InteractNearest:PLAYER_REGEN_ENABLED(event)
	-- Called by ImmersiveAction:PLAYER_REGEN_ENABLED(event)
	-- to update OverridesIn.InteractNearest.*
	-- in StartTackingUnit(), before OverrideBindings:OverrideCommands(..)
	Log.Event(event)
	self:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
	self:RegisterEvent('PLAYER_TARGET_CHANGED')

	-- Try to do  /targetlastenemy  after leaving combat.
	if event == 'PLAYER_REGEN_ENABLED' then  self.TargetLastHostile = 'TARGETLASTHOSTILE'  end

	-- Update TargetCommand in protected environment in case :SetTargetCommand() was called in combat.
	self:SetTargetCommand(self.TargetCommand)

	-- StartTacking() -> OverrideBindings() will use the uploaded TargetCommand.
	self:StartTacking()
end


function InteractNearest:PLAYER_REGEN_DISABLED(event)
	Log.Event(event)
	self:UnregisterEvent('UPDATE_MOUSEOVER_UNIT')
	self:UnregisterEvent('PLAYER_TARGET_CHANGED')
	self:Hide()    -- Stop OnUpdate() calls.
end


---------------------------------
-- Enable if there are dynamic bindings:  OverridesIn.InteractNearest[dynamicCommand]
---------------------------------

function InteractNearest:Activate()
	local active =  self.enabled  and  nil~=next(self.DynamicKeys)
	if  not self.active == not active  then  return nil  end
	self.active = active
	IA.commandState.InteractNearest = active

	if active then
		self:RegisterEvent('PLAYER_REGEN_DISABLED')
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
		self:PLAYER_REGEN_ENABLED('Enable(true)')
	else
		self:UnregisterEvent('PLAYER_REGEN_DISABLED')
		self:UnregisterEvent('PLAYER_REGEN_ENABLED')
		self:PLAYER_REGEN_DISABLED('Enable(false)')
	end
	return active
end


-- InteractNearest:CaptureBindings() is a bit different from OverrideBindings:CaptureBindings()
-- as it stores  key -> toCmd  in DynamicKeys, more suitable for the InCombatHandler.
function InteractNearest:UpdateOverrideBindings()
	self.DynamicKeys = self.CaptureBindings(self.Overrides)

	local handler = self.InCombatHandler
	if handler.InitSecureHandler then  handler:InitSecureHandler()  end
	handler:UploadKeys(self.DynamicKeys)

	self:Activate()
end


function InteractNearest:Enable(enable)
	if  not self.enable == not enable  then  return nil  end
	self.enabled = not not enable
	self:Activate()
	return true
end


function InteractNearest.CaptureBindings(overrides)
	local DynamicKeys = {}
	for fromCmd,macroCondition in pairs(overrides) do
		local keys = { GetBindingKey(fromCmd) }
		for i,key in ipairs(keys) do
			LibShared.softassert(not DynamicKeys[key], "")
			DynamicKeys[key] = fromCmd
		end
	end
	return DynamicKeys
end




---------------------------------
-- Check if targeted unit is a good candidate for interaction.
-- This happens on when target or mouseover changes.
---------------------------------

local function CheckUnitIsInteractable(unit)
	-- return  UnitExists(unit)
	return  UnitIsFriend('player', unit)  -- not PlayerCanAttack(unit)
		and  not UnitIsPlayer(unit)         -- not PlayerCanAssist(unit)
		-- The "Ethereal Vendor" is PlayerControlled, but also follows you around, therefore pointless for auto-targeting.
		and  not UnitPlayerControlled(unit)
		-- and  not UnitIsDead(unit)
		and  not UnitIsUnit(unit, 'npc')       -- Already interacting with a vendor, target next nearest.
		and  not UnitIsUnit(unit, 'questnpc')  -- Already interacting with a quest giver, target next nearest.
end

local function CheckUnitIsLootable(unit)
	return  UnitIsEnemy('player', unit)
		and  UnitIsDead(unit)    -- loot
		-- and  select(2, CanLootUnit( UnitGUID(unit) ))
	-- local hasLoot, canLoot = CanLootUnit( UnitGUID(unit)) )
end


function InteractNearest:StartTackingUnit(unit)
	print("InteractNearest:StartTackingUnit("..unit..")")

	local interact = CheckUnitIsInteractable(unit)
	local loot = not interact and CheckUnitIsLootable(unit)
	-- Check whether to track this unit.
	if  not interact  and  not loot  then
		-- Don't replace monitored unit with a non-interactable unit.
		if  self.trackedUnit ~= unit  then  return  false  end
		-- trackedUnit is no longer interactable. Stop monitoring.
		unit = nil
	elseif loot then
		-- Managed to target a lootable corpse, don't do TARGETLASTHOSTILE anymore.
		self.TargetLastHostile = nil
	end

	print("InteractNearest:StartTackingUnit(..) -> new trackedUnit = "..tostring(unit))
	self.trackedUnit = unit
	self.InteractCommand = unit == 'mouseover' and 'INTERACTMOUSEOVER' or 'INTERACTTARGET'

	-- Enable OnUpdate monitor if there is a tracked unit.
	self:SetShown(unit ~= nil)
	self:UpdateInteractBinding()
	return unit
end


---------------------------------
-- Periodically check distance of tracked unit
---------------------------------

function InteractNearest:UpdateInteractBinding()
	local unit = self.trackedUnit
	local interact =  unit  and  CheckInteractDistance(unit, self.InteractRange)
	local command =
  interact  and  self.InteractCommand
		or  self.TargetLastHostile
		or  self.TargetCommand	

	if  command == self.currentBinding  then  return  end		-- no changes
	self.currentBinding = command

	-- Override the bindings with the new command.
	-- This cannot be called InCombatLockdown().
	-- Do with the handler.
	-- self.InCombatHandler:SetAttribute('INTERACTNEAREST', command)
	-- Do it directly.
	self:OverrideBindingOutOfCombat(command)
end


