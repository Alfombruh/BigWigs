--------------------------------------------------------------------------------
-- TODO List:
-- - Blood Frenzy not tested yet, only journal data
-- - Only heroic timers (raid test 15.01.16)
-- - Respawn time
-- - Tuning sounds / message colors
-- - Remove alpha engaged message

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Ursoc", 1094, 1667)
if not mod then return end
mod:RegisterEnableMob(100497)
mod.engageId = 1841
-- mod.respawnTime = 0 -- TODO

--------------------------------------------------------------------------------
-- Locals
--

local cacophonyCount = 1
local rendFleshCount = 1
local focusedGazeCount = 1

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		197969, -- Roaring Cacophony
		{197943, "TANK"}, -- Overwhelm
		204859, -- Rend Flesh
		{198006, "ICON", "FLASH", "SAY"}, -- Focused Gaze
		198108, -- Unbalanced
		205611, -- Miasma
		198388, -- Blood Frenzy
		"berserk",
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_CAST_START", "RoaringCacophony", 197969)
	self:Log("SPELL_CAST_SUCCESS", "RoaringCacophonySuccess", 197969)
	self:Log("SPELL_AURA_APPLIED", "Overwhelm", 197943)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Overwhelm", 197943)
	self:Log("SPELL_CAST_START", "RendFleshCast", 197942)
	self:Log("SPELL_AURA_APPLIED", "RendFlesh", 204859)
	self:Log("SPELL_AURA_APPLIED", "FocusedGaze", 198006)
	self:Log("SPELL_AURA_REMOVED", "FocusedGazeRemoved", 198006)
	self:Log("SPELL_AURA_APPLIED", "Unbalanced", 198108)
	self:Log("SPELL_AURA_APPLIED", "MiasmaDamage", 205611)
	self:Log("SPELL_PERIODIC_DAMAGE", "MiasmaDamage", 205611)
	self:Log("SPELL_PERIODIC_MISSED", "MiasmaDamage", 205611)
	self:Log("SPELL_AURA_APPLIED", "BloodFrenzy", 198388)
end

function mod:OnEngage()
	self:Message("berserk", "Neutral", nil, "Ursoc (Alpha) Engaged", 98204) -- Amani Battle Bear icon
	cacophonyCount = 1
	rendFleshCount = 1
	focusedGazeCount = 1
	self:Bar(197943, 10) -- Overwhelm
	self:Bar(204859, 15, CL.count:format(self:SpellName(204859), rendFleshCount)) -- Rend Flesh
	self:Bar(198006, 19, CL.count:format(self:SpellName(198006), focusedGazeCount)) -- Focused Gaze
	self:Bar(197969, 40, CL.count:format(self:SpellName(197969), cacophonyCount)) -- Roaring Cacophony
	self:Berserk(300)
	self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", nil, "boss1")
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:RoaringCacophony(args)
	self:Message(args.spellId, "Urgent", nil, CL.casting:format(CL.count:format(args.spellName, cacophonyCount)))
end

function mod:RoaringCacophonySuccess(args)
	self:Message(args.spellId, "Urgent", "Alarm", CL.count:format(args.spellName, cacophonyCount))
	cacophonyCount = cacophonyCount + 1
	self:Bar(args.spellId, cacophonyCount % 2 == 0 and 10 or 30, CL.count:format(args.spellName, cacophonyCount))
end

function mod:Overwhelm(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "Important", amount > 1 and "Warning")
	self:Bar(args.spellId, 10)
end

function mod:RendFleshCast(args)
	if self:Tank() or self:Healer() then
		self:Message(204859, "Attention", nil, CL.casting:format(CL.count:format(args.spellName, rendFleshCount)))
	end
end

function mod:RendFlesh(args)
	self:TargetMessage(args.spellId, args.destName, "Attention", (self:Tank() or self:Healer()) and "Info", CL.count:format(args.spellName, rendFleshCount))

	-- This might be 12s for every difficulty, but we only know heroic alpha right now
	local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
	local t = expires - GetTime()
	self:TargetBar(args.spellId, t, args.destName, CL.count:format(args.spellName, rendFleshCount))

	rendFleshCount = rendFleshCount + 1
	self:Bar(args.spellId, 20, CL.count:format(args.spellName, rendFleshCount))
end

function mod:FocusedGaze(args)
	if self:Me(args.destGUID) then
		self:Flash(args.spellId)
		self:Say(args.spellId)
	end
	self:PrimaryIcon(args.spellId, args.destName)
	self:TargetMessage(args.spellId, args.destName, "Important", "Warning", CL.count:format(args.spellName, focusedGazeCount), args.spellId, true)
	self:TargetBar(args.spellId, 6, args.destName)
	focusedGazeCount = focusedGazeCount + 1
	self:Bar(args.spellId, 40, CL.count:format(args.spellName, focusedGazeCount))
end

function mod:FocusedGazeRemoved(args)
	self:StopBar(args.spellId, args.destName)
	self:PrimaryIcon(args.spellId, nil)
end

function mod:Unbalanced(args)
	if self:Me(args.destGUID) then
		-- This might be 50s for every difficulty, but we only know heroic alpha right now
		local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
		local t = expires - GetTime()
		self:TargetBar(args.spellId, t, args.destName)
	end
end

do
	local prev = 0
	function mod:MiasmaDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 1.5 then
			prev = t
			self:Message(args.spellId, "Personal", "Alert", CL.underyou:format(args.spellName))
		end
	end
end

function mod:UNIT_HEALTH_FREQUENT(unit)
	local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
	if hp < 35 then -- Blood Frenzy at 30%
		self:UnregisterUnitEvent("UNIT_HEALTH_FREQUENT", unit)
		self:Message(198388, "Neutral", "Info", CL.soon:format(self:SpellName(198388))) -- Blood Frenzy
	end
end

function mod:BloodFrenzy(args)
	self:Message(args.spellId, "Important", "Alarm")
end
