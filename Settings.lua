local G, ADDON_NAME, ADDON = _G, ...
local IA = G.ImmersiveAction or {}  ;  G.ImmersiveAction = IA
-- local Log = IA.Log or {}  ;  IA.Log = Log

local indexOf = G.LibShared.Require.indexOf



---------------------------
-- Default configuration
---------------------------

IA.defaultSettings = {
	--global = { version = "1.0.0", },
	profile = {
		enabledOnLogin = false,
		enableWithMoveKeys = false,
		disableWithLookAround = true,
		enableAfterTurning = true,
		enableAfterMoveAndSteer = true,
		-- actionModeMoveWithCameraButton = false,
		preventSingleClickMouseover = true,
		preventSingleClick = false,
		runToDoubleClickMouseover = true,
		bindingsInActionMode = {},
		bindingsInGeneral = {  -- 2019-02-28:
			--['BUTTON1']				= "INTERACTNEAREST",
			-- ['BUTTON1']				= "CAMERAORSELECTORMOVE",  -- Rotate Camera (LeftButton default),
			-- ['BUTTON2']				= "TURNORACTION",  -- Turn or Action (RightButton default),
			['ALT-BUTTON1']		= "MOVEFORWARD",
			['ALT-BUTTON2']		= "MOVEBACKWARD",
			['SHIFT-BUTTON1'] = "STRAFELEFT",
			['SHIFT-BUTTON2'] = "STRAFERIGHT",
			['CTRL-BUTTON1']	= "INTERACTNEAREST",
			['CTRL-BUTTON2']	= "INTERACTMOUSEOVER",  -- Does INTERACTTARGET if there is nothing under the mouse (no mouseover)
			-- ['ALT-BUTTON4']	= "AUTORUN",
			-- ['BUTTON5']	    = "AUTORUN",
			-- ['CTRL-BUTTON4']	= "ToggleActionMode",
			--[[
			['BUTTON1']				= "MOVEANDSTEER",
			['BUTTON2']				= "TURNORACTION",
			['ALT-BUTTON1']		= "CAMERAORSELECTORMOVE",  -- Rotate Camera (LeftButton default),
			['ALT-BUTTON2']		= "TURNORACTION",  -- Turn or Action (RightButton default),
			['SHIFT-BUTTON1'] = "TARGETNEARESTFRIEND",
			['SHIFT-BUTTON2'] = "TARGETNEARESTENEMY",
			['CTRL-BUTTON1']	= "INTERACTNEAREST",
			['CTRL-BUTTON2']	= "INTERACTMOUSEOVER",  -- Does INTERACTTARGET if there is nothing under the mouse (no mouseover)
			--]]
			--[[
			['BUTTON1']				= "INTERACTNEAREST",
			--['BUTTON1']				= "MOVEANDSTEER",
			['BUTTON2']				= "TARGETSCANENEMY",
			['ALT-BUTTON1']		= "CAMERAORSELECTORMOVE",  -- Rotate Camera (LeftButton default),
			['ALT-BUTTON2']		= "TURNORACTION",  -- Turn or Action (RightButton default),
			['SHIFT-BUTTON1'] = LibShared.softassert(UIShortcuts.FocusMouseoverBinding),
			['SHIFT-BUTTON2'] = "TARGETNEARESTENEMY",
			['CTRL-BUTTON1']	= "INTERACTMOUSEOVER",  -- Does INTERACTTARGET if there is nothing under the mouse (no mouseover)
			['CTRL-BUTTON2']	= "INTERACTNEAREST",
			--]]
			--[[
			['SHIFT-BUTTON1'] = "TARGETMOUSEOVER",
			['SHIFT-BUTTON2'] = LibShared.softassert(UIShortcuts.FocusMouseoverBinding),
			['SHIFT-BUTTON1'] = "TARGETPREVIOUSFRIEND",
			['CTRL-BUTTON1']	= "TARGETNEARESTFRIEND",
			['CTRL-BUTTON2']	= "INTERACTTARGET",
			--]]
		},
		modifiers = {
		},
	}
}




-------------------
-- Configuration
-------------------

local Config = {}
IA.Config = Config
Config.modifierKeys = { '', 'SHIFT', 'CTRL', 'ALT' }

function Config:InitOptionsFrame()
	if self.optionsFrame then  return  end
	--self.InitCommandLabels()
	--self.InitOptionsTable()
	local name = IA.name or 'ImmersiveAction'
	LibStub("AceConfig-3.0"):RegisterOptionsTable(name, self.optionsTable)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(name, name)
end

--[[ Commands vocabulary:
MouseTurn (turn character with mouse) = Mouselook (term from Blizzard - Wow lua api)
FreeCameraMode = look around with camera, while the character does not change direction.
	- only possible with CAMERAORSELECTORMOVE command and disabled MouselookMode
--]]

Config.commands = { 
		'',		-- don't override --

		'CAMERAORSELECTORMOVE',			-- Left Button default:  rotate camera or target mouseover.  Disables Mouselook when pressed, otherwise it acts as MoveAndSteer.
		'TURNORACTION',							-- Right Button default:  Mouselook if hold, InteractMouseover if clicked
		'TurnWithoutInteract',			-- Turn with mouse, no actions
		'ReleaseCursor',            -- Switch back to CursorMode while pressed.
		'ToggleActionMode',

		-- Interact
		'INTERACTMOUSEOVER',				-- select with mouse + interact, no turning or camera
		-- hook mouse button directly to disable Mouselook while pressed
		-- or override with COMBATMODE_DISABLE
		'INTERACTTARGET',						-- no select, only interact
		-- any valid use-cases for this?

		-- Target (select with mouse)
		'INTERACTNEAREST',	          -- could override INTERACTMOUSEOVER instead: without cursor (in ActionMode) it has no effect
		'TARGETSCANENEMY',						-- target npc/player in crosshair (middle of screen), can be far away, with turning/lock (Mouselook)
		'TARGETNEARESTENEMY',					-- target nearest, no turning

		'TARGETMOUSEOVER',						-- no turning or camera -> hook mouse button directly to disable Mouselook while pressed
		UIShortcuts.FocusMouseoverBinding,    -- no turning or camera

		-- Target Nearest (tab targeting, no turning or camera, mouse influences direction to look for the nearest)
		'TARGETNEARESTFRIENDPLAYER',
		'TARGETNEARESTENEMYPLAYER',
		'TARGETNEARESTFRIEND',				-- SmartTarget uses it; this one is less useful, candidate for removal
		'TARGETPREVIOUSFRIEND',

		-- Move
		'MOVEANDSTEER',
		'TOGGLEAUTORUN',

		'MOVEFORWARD',
		'MOVEBACKWARD',
		'STRAFELEFT',
		'STRAFERIGHT',
		'JUMP',
		'SITORSTAND',

		-- ActionBar
		'ACTIONBUTTON1',
		'ACTIONBUTTON2',
		'ACTIONBUTTON3',
		'ACTIONBUTTON4',
		'ACTIONBUTTON5',
		'ACTIONBUTTON6',
		'ACTIONBUTTON7',
		'ACTIONBUTTON8',
		'ACTIONBUTTON9',
		'ACTIONBUTTON10',
		'ACTIONBUTTON11',
		'ACTIONBUTTON12',
}


Config.commandLabelsCustom = {
	[''] 													= "-- don't override --",
	--[[
	['CAMERAORSELECTORMOVE'] = "Rotate Camera",		 -- targeting  or  camera rotation, original binding of BUTTON1
	['TURNORACTION']         = "Turn or Action",	 -- the original binding of BUTTON2
	['INTERACTNEAREST']      = "Target and interact with closest friendly npc",
	[UIShortcuts.FocusMouseoverBinding]  = "Focus Mouseover",	 -- no turning or camera
	--]]
}






function Config:GetCommandLabel(command)
	return self.commandLabelsCustom[command]  or  G['BINDING_NAME_'.. command]  or  command
end

function Config:InitCommandLabels()
	if  self.commandLabels  then  return self.commandLabels  end
	self.commandLabels = {}
	for  i,command  in  ipairs(self.commands)  do
		local label = self:GetCommandLabel(command)
		table.insert(self.commandLabels, label)
	end
	return self.commandLabels
end

--Config:InitCommandLabels()



local optCnt = 0
local function optBind(key, name, desc, defValues)
	optCnt = optCnt + 1
	local optInfo = {
		name = name,
		desc = desc,
		order = optCnt,
		type = "select",
		--width = "full",
		values = defValues or Config:InitCommandLabels(),
		get = function()
			local value = IA.db.profile.bindingsInGeneral[key]
			return  indexOf(Config.commands, value)
		end,
		set = function(info, idx)
			local value = Config.commands[idx]
			if value=='' then  value = nil  end
			IA.UserBindings:SetUserBinding('General', key, value)
		end,
	}
	Config.optionsTable.args[key] = optInfo
	return optInfo
end

local function optMod(action, name, desc, defValues)
	optCnt = optCnt + 1
	local optInfo = {
		name = name,
		desc = desc,
		order = optCnt,
		type = "select",
		--width = "full",
		values = Config.modifierKeys,
		get = function()
			local value = IA.db.profile.modifiers[action]
			return  indexOf(Config.modifierKeys, value)
		end,
		set = function(info, idx)
			--if  value == ''  or  value == 'NONE'  then  value = nil  end
			IA.db.profile.modifiers[action] = Config.modifierKeys[idx]
		end,
	}
	Config.optionsTable.args[action] = optInfo
	return optInfo
end

local function optToggle(key, name, desc)
	optCnt = optCnt + 1
	local optInfo = {
		name = name,
		desc = desc,
		order = optCnt,
		type = "toggle",
		--width = "full",
		-- setting = link(db).profile[key],
		get = function()  return IA.db.profile[key]  end,
		set = function(info, value)
			IA.db.profile[key] = value
		end,
	}
	Config.optionsTable.args[key] = optInfo
	return optInfo
end


Config.optionsTable = { 
	name = "Immersive Action Settings",
	handler = IA,
	type = "group",
	args = {},
}

Config.optionsTableList = { 
	optBind("BUTTON1", "Left Click", "Override original behavior of Left Mouse Button"),
	optBind("BUTTON2", "Right Click", "Override original behavior of Right Mouse Button"),
	optBind("BUTTON3", "Wheel Click", "Clicking Mouse Wheel"),
	optBind("ALT-BUTTON1", "Alt + Left Click"),
	optBind("ALT-BUTTON2", "Alt + Right Click"),
	optBind("ALT-BUTTON3", "Alt + Wheel Click"),
	optBind("SHIFT-BUTTON1", "Shift + Left Click"),
	optBind("SHIFT-BUTTON2", "Shift + Right Click"),
	optBind("SHIFT-BUTTON3", "Shift + Wheel Click"),
	optBind("CTRL-BUTTON1", "Control + Left Click"),
	optBind("CTRL-BUTTON2", "Control + Right Click"),
	optBind("CTRL-BUTTON3", "Control + Wheel Click"),
	optBind("BUTTON4", "Back Click", "Navigate Back Mouse Button"),
	optBind("BUTTON5", "Next Click", "Navigate Forward Mouse Button"),
	optBind("X0", ""),
	optBind("ALT-BUTTON4", "Alt + Back Click"),
	optBind("ALT-BUTTON5", "Alt + Next Click"),
	-- optBind("X1", ""),
	optToggle("enabledOnLogin", "Enable on login", "Surprise your little brother/sister next time he/she logs in."),
	optToggle("enableWithMoveKeys", "Enable while moving", "While pressing any movement key the mouse will turn the camera and your character."),
	optToggle("disableWithLookAround", "Disable with Left click", "Pressing LeftButton (turning the camera) will disable ActionMode."),
	optToggle("enableAfterTurning", "Enable with Right click", "Pressing RightButton (turning your character) will enable ActionMode."),
	optToggle("enableAfterMoveAndSteer", "Enable with Move and steer", "Pressing MoveAndSteer will enable ActionMode."),
	-- optToggle("actionModeMoveWithCameraButton", "Move with LeftButton", "Effective in ActionMode:  You will move forward while pressing LeftButton. Try RightButton as well, and the two together (MouseCursorMode, LookAroundMode)"),
	optToggle("preventSingleClickMouseover", "Prevent accidental rightclick over units", "Single rightclick over units won't attack/interact the mouseover unit.\n".."Double-click to interact."),
	optToggle("preventSingleClick", "Prevent accidental rightclick everywhere", "Single rightclick won't attack/interact or click objects.\n".."Double-click to interact."),
	optToggle("runToDoubleClickMouseover", "Run to double-clicked unit", "Double-click a unit to run up to it and interact."),
	optMod("enableModifier", "Enable with modifier:", "While pressing this modifier the camera turns with the mouse."),
	optMod("disableModifier", "Disable with modifier:", "While pressing this modifier the mouse cursor is free to move."),
	--optBind("smarttargeting", "Smart Targeting", "Buttons that target the closest friendly NPC and interact with it if close enough", SmartTargetValues),
}

