--[[ Simple AutoCarry Plugin with an enhanced skill use ]]--

--[[ Config ]]--
-- set up all hotkeys
local HK1 = string.byte("Y") -- Harass
local HK2 = string.byte("W") -- cage nearest enemy
local HK3 = string.byte("N") -- jungle clearing

--[[ Variables ]]--
local SpellRangeQ = 650 -- q range
local SpellRangeW = 625 -- w range
local SpellRangeE = 675 -- e range
local SpellRangeR = 200 -- AOE range
local levelSequence = {nil,0,3,1,1,4,1,2,1,2,4,2,2,3,3,4,3,3} -- we level the spells that way, first point free
local floattext = {"Harass him","Fight him","Kill him","Murder him"} -- text assigned to enemys
local killable = {} -- our enemy array where stored if people are killable
local waittxt = {} -- prevents UI lags, all credits to Dekaron
local QREADY, WREADY, EREADY, RREADY, DFGReady, HXGReady, SEReady, IGNITEReady = false, false, false, false, false, false, false, false -- item/ignite cooldown
local DFGSlot, HXGSlot, SESlot, SHEENSlot, TRINITYSlot, LICHBANESlot = nil, nil, nil, nil, nil, nil -- item slots
local enemyMinions = minionManager(MINION_ENEMY, SpellRangeQ, player, MINION_SORT_HEALTH_ASC)

--[[ Core ]]--
function PluginOnLoad()
	AutoCarry.PluginMenu:addParam("harass", "Harass", SCRIPT_PARAM_ONKEYDOWN, false, HK1) -- harass
	AutoCarry.PluginMenu:addParam("cage", "Cage nearest enemy", SCRIPT_PARAM_ONKEYDOWN, false, HK2) -- cage
	AutoCarry.PluginMenu:addParam("jungle", "Jungle clearing", SCRIPT_PARAM_ONKEYTOGGLE, false, HK3) -- jungle clearing

	-- Settings
	AutoCarry.PluginMenu:addParam("lcSkills", "Use Skills with Lane Clear mode", SCRIPT_PARAM_ONOFF, true) -- spamming q/w/e on the minions while lane clearing
	AutoCarry.PluginMenu:addParam("aUlti", "Use Ulti in Full Combo", SCRIPT_PARAM_ONOFF, true) -- decide if ulti should be used in full combo
	AutoCarry.PluginMenu:addParam("aItems", "Use Items in Full Combo", SCRIPT_PARAM_ONOFF, true) -- decide if items should be used in full combo
	AutoCarry.PluginMenu:addParam("aIGN", "Auto Ignite", SCRIPT_PARAM_ONOFF, true) -- decide if summoner spells should be used automatic
	AutoCarry.PluginMenu:addParam("hwQ", "Harass with Q", SCRIPT_PARAM_ONOFF, true) -- Harass with Q
	AutoCarry.PluginMenu:addParam("hwE", "Harass with E", SCRIPT_PARAM_ONOFF, true) -- Harass with E
	AutoCarry.PluginMenu:addParam("hwW", "Harass with W", SCRIPT_PARAM_ONOFF, false) -- Harass with W
	AutoCarry.PluginMenu:addParam("aSkills", "Auto Level Skills (Requires Reload)", SCRIPT_PARAM_ONOFF, true) -- auto level skills
	AutoCarry.PluginMenu:addParam("lhQ", "Last hit with Q", SCRIPT_PARAM_ONOFF, true) -- Last hit with Q
	AutoCarry.PluginMenu:addParam("lhQM", "Last hit until Mana", SCRIPT_PARAM_SLICE, 50, 0, 100, 2)
	AutoCarry.PluginMenu:addParam("ks", "KS with all Skills", SCRIPT_PARAM_ONOFF, true) -- KS with Q

	-- Visual
	AutoCarry.PluginMenu:addParam("draw", "Draw Circles", SCRIPT_PARAM_ONOFF, false) -- Draw Circles

	-- perma show HK1-4
	AutoCarry.PluginMenu:permaShow("harass")
	AutoCarry.PluginMenu:permaShow("cage")
	AutoCarry.PluginMenu:permaShow("jungle")

	if AutoCarry.PluginMenu.aSkills then -- setup the skill autolevel
		autoLevelSetSequence(levelSequence)
		autoLevelSetFunction(onChoiceFunction) -- add the callback to choose the first skill
	end

	IGNITESlot = ((myHero:GetSpellData(SUMMONER_1).name:find("SummonerDot") and SUMMONER_1) or (myHero:GetSpellData(SUMMONER_2).name:find("SummonerDot") and SUMMONER_2) or nil) -- do we have ignite?
	
	for i=1, heroManager.iCount do waittxt[i] = i*3 end -- All credits to Dekaron

	AutoCarry.SkillsCrosshair.range = SpellRangeE
end

function PluginOnTick()
	CooldownHandler() -- figure out which things are on cd
	DMGCalculation() -- calculate killable targets

	if SEReady and (myHero.health / myHero.maxHealth <= 0.3) then CastItem(3040) end -- use seraphs embrace

	if not myHero.dead then
		if AutoCarry.PluginMenu.ks then KS() end -- Get the kill
		if AutoCarry.MainMenu.AutoCarry then FullCombo() end -- run full combo
		if AutoCarry.PluginMenu.harass then Harass() end -- harass
		if AutoCarry.PluginMenu.cage then CageNearestEnemy() end -- cage the nearest enemy
		if AutoCarry.PluginMenu.lcSkills and AutoCarry.MainMenu.LaneClear then LaneClear() end -- spamming q/w/e on the minions while lane clearing
		if AutoCarry.MainMenu.LastHit and AutoCarry.PluginMenu.jungle then JungleSteal() end -- last hit the jungle mobs
		if AutoCarry.MainMenu.LaneClear and AutoCarry.PluginMenu.jungle then JungleClear() end -- kill jungle mobs with abilities
		if AutoCarry.PluginMenu.lhQ and not (AutoCarry.MainMenu.AutoCarry or AutoCarry.PluginMenu.harass or AutoCarry.PluginMenu.cage or AutoCarry.PluginMenu.jungle) and (((myHero.mana/myHero.maxMana)*100) >= AutoCarry.PluginMenu.lhQM) then QLastHit() end -- Q last hit
	end
end

function PluginOnDraw()
	if not myHero.dead and AutoCarry.PluginMenu.draw then
		for i=1, heroManager.iCount do
			local Unit = heroManager:GetHero(i)
			if ValidTarget(Unit) then -- we draw our circles
				 if killable[i] == 1 then
				 	DrawCircle(Unit.x, Unit.y, Unit.z, 100, 0xFFFFFF00)
				 end

				 if killable[i] == 2 then
				 	DrawCircle(Unit.x, Unit.y, Unit.z, 100, 0xFFFFFF00)
				 end

				 if killable[i] == 3 then
				 	for j=0, 10 do
				 		DrawCircle(Unit.x, Unit.y, Unit.z, 100+j*0.8, 0x099B2299)
				 	end
				 end

				 if killable[i] == 4 then
				 	for j=0, 10 do
				 		DrawCircle(Unit.x, Unit.y, Unit.z, 100+j*0.8, 0x099B2299)
				 	end
				 end

				 if waittxt[i] == 1 and killable[i] ~= 0 then
				 	PrintFloatText(Unit,0,floattext[killable[i]])
				 end
			end

			if waittxt[i] == 1 then
				waittxt[i] = 30
			else
				waittxt[i] = waittxt[i]-1
			end

		end
	end
end

function PluginOnProcessSpell(unit, spell)
	if ValidTarget(unit, SpellRangeW) and UnderTurret(unit, false) and GetDistance(spell.endPos, myHero) < 10 and WREADY then CastSpell(_W, unit) end -- Thanks to Apple
end

function KS() -- get the kills
	for i=1, heroManager.iCount do
		local killableEnemy = heroManager:GetHero(i)
		if ValidTarget(killableEnemy,SpellRangeQ) and QREADY and (getDmg("Q", killableEnemy, myHero) >= killableEnemy.health) then CastSpell(_Q, killableEnemy) end
		if ValidTarget(killableEnemy, SpellRangeE) and EREADY and (getDmg("E", killableEnemy, myHero) >= killableEnemy.health) then CastSpell(_E, killableEnemy) end
		if ValidTarget(killableEnemy, SpellRangeW) and WREADY and (getDmg("W", killableEnemy, myHero) >= killableEnemy.health) then CastSpell(_W, killableEnemy) end
	end
end

function FullCombo()
	local cdr = math.abs(myHero.cdr*100) -- our cooldown reduction
	local target = AutoCarry.GetAttackTarget(true)
	local calcenemy = 1

	if not ValidTarget(target) then return true end

	for i=1, heroManager.iCount do
    	local Unit = heroManager:GetHero(i)
    	if Unit.charName == target.charName then
    		calcenemy = i
    	end
   	end

    if (killable[calcenemy] == 2 or killable[calcenemy] == 3) and DFGReady then
    	CastSpell(DFGSlot, target)
    end

    if (killable[calcenemy] == 2 or killable[calcenemy] == 3) and HXGReady then
    	CastSpell(HXGSlot, target)
    end

    if killable[calcenemy] == 2 and AutoCarry.PluginMenu.aIGN and IGNITEReady then
    	CastSpell(IGNITESlot, target)
    end

    if cdr <= 20 then
    	if ValidTarget(target, SpellRangeQ) and QREADY then CastSpell(_Q, target) end
    	if ValidTarget(target, SpellRangeW) and WREADY then CastSpell(_W, target) end
    	if ValidTarget(target, SpellRangeE) and EREADY then CastSpell(_E, target) end
    	UseUlti(target)
    elseif cdr > 20 and cdr < 30 then
    	if ValidTarget(target, SpellRangeQ) and QREADY then CastSpell(_Q, target) end
    	if ValidTarget(target, SpellRangeE) and EREADY then CastSpell(_E, target) end
    	if ValidTarget(target, SpellRangeW) and WREADY then CastSpell(_W, target) end
    	UseUlti(target)
    else
    	if ValidTarget(target, SpellRangeQ) and QREADY then CastSpell(_Q, target) end
    	UseUlti(target)
		if ValidTarget(target, SpellRangeW) and WREADY then CastSpell(_W, target) end
		if ValidTarget(target, SpellRangeE) and EREADY then CastSpell(_E, target) end
	end
end

function Harass()
	local target = AutoCarry.GetAttackTarget(true)
	if ValidTarget(target) then
		if AutoCarry.PluginMenu.hwQ and QREADY and (GetDistance(target) <= SpellRangeQ) then CastSpell(_Q, target) end
		if AutoCarry.PluginMenu.hwW and WREADY and (GetDistance(target) <= SpellRangeW) then CastSpell(_W, target) end
		if AutoCarry.PluginMenu.hwE and EREADY and (GetDistance(target) <= SpellRangeE) then CastSpell(_E, target) end
	end
	myHero:MoveTo(mousePos.x, mousePos.z)
end

function CageNearestEnemy()
	local NearestEnemy = nil
	for _, enemy in pairs(GetEnemyHeroes()) do
		if not enemy.valid then return true end -- may be removed again
		if ValidTarget(enemy) and NearestEnemy == nil or GetDistance(enemy) < GetDistance(NearestEnemy) then
			NearestEnemy = enemy
		end
	end

	if ValidTarget(NearestEnemy, SpellRangeW) then CastSpell(_W, NearestEnemy) end -- Cage him
end

function JungleClear()
	local Priority = nil
	local Target = nil
	for _, mob in pairs(AutoCarry.GetJungleMobs()) do
		if ValidTarget(mob) then
 			if mob.name == "TT_Spiderboss7.1.1"
			or mob.name == "Worm12.1.1"
			or mob.name == "Dragon6.1.1"
			or mob.name == "AncientGolem1.1.1"
			or mob.name == "AncientGolem7.1.1"
			or mob.name == "LizardElder4.1.1"
			or mob.name == "LizardElder10.1.1"
			or mob.name == "GiantWolf2.1.3"
			or mob.name == "GiantWolf8.1.3"
			or mob.name == "Wraith3.1.3"
			or mob.name == "Wraith9.1.3"
			or mob.name == "Golem5.1.2"
			or mob.name == "Golem11.1.2"
			then
				Priority = mob
			else
				Target = mob
			end
		end
	end

	if Priority then
		Target = Priority
	end

	if ValidTarget(Target) then
		if myHero:GetDistance(Target) <= SpellRangeQ then CastSpell(_Q, Target) end
		if myHero:GetDistance(Target) <= SpellRangeW then CastSpell(_W, Target) end
		if myHero:GetDistance(Target) <= SpellRangeE then CastSpell(_E, Target) end
	end
end

function JungleSteal()
	for _, mob in pairs(AutoCarry.GetJungleMobs()) do
		if ValidTarget(mob, SpellRangeQ) and QREADY and (getDmg("Q", mob, myHero) >= mob.health) then CastSpell(_Q, mob) end
		if ValidTarget(mob, SpellRangeE) and EREADY and (getDmg("E", mob, myHero) >= mob.health) then CastSpell(_E, mob) end
		if ValidTarget(mob, SpellRangeW) and WREADY and (getDmg("W", mob, myHero) >= mob.health) then CastSpell(_W, mob) end
	end
end

function LaneClear()
	enemyMinions:update() -- get the newest minions
	for index, minion in pairs(enemyMinions.objects) do -- loop through the minions
		if ValidTarget(minion) then
			if EREADY and (GetDistance(minion) <= SpellRangeE) then CastSpell(_E, minion) end
			if QREADY and (GetDistance(minion) <= SpellRangeQ) then CastSpell(_Q, minion) end
			if WREADY and (GetDistance(minion) <= SpellRangeW) then CastSpell(_W, minion) end
		end
	end
end

function QLastHit()
	enemyMinions:update() -- get the newest minions
	for index, minion in pairs(enemyMinions.objects) do -- loop through the minions
    	if ValidTarget(minion, SpellRangeQ) and QREADY then -- check if q is ready and the minion attackable
        	if minion.health <= getDmg("Q", minion, myHero) then -- check if we do enough dmg
            	CastSpell(_Q, minion)	-- kill the minion
            end 
        end
    end
end

function CooldownHandler()
	DFGSlot, HXGSlot, SESlot, SHEENSlot, TRINITYSlot, LICHBANESlot = GetInventorySlotItem(3128), GetInventorySlotItem(3146), GetInventorySlotItem(3040), GetInventorySlotItem(3057), GetInventorySlotItem(3078), GetInventorySlotItem(3100)
	QREADY = (myHero:CanUseSpell(_Q) == READY)
	WREADY = (myHero:CanUseSpell(_W) == READY)
	EREADY = (myHero:CanUseSpell(_E) == READY)
	RREADY = (myHero:CanUseSpell(_R) == READY)
	DFGReady = (DFGSlot ~= nil and myHero:CanUseSpell(DFGSlot) == READY)
	HXGReady = (HXGSlot ~= nil and myHero:CanUseSpell(HXGSlot) == READY)
	SEReady = (SESlot ~= nil and myHero:CanUseSpell(SESlot) == READY)
	IGNITEReady = (IGNITESlot ~= nil and myHero:CanUseSpell(IGNITESlot) == READY)
end

function DMGCalculation() -- our whole damage calculation
	for i=1, heroManager.iCount do
        local Unit = heroManager:GetHero(i)
        if ValidTarget(Unit) then
        	local DFGDamage, HXGDamage, LIANDRYSDamage, IGNITEDamage, SHEENDamage, TRINITYDamage, LICHBANEDamage = 0, 0, 0, 0, 0, 0, 0
        	local QDamage = getDmg("Q",Unit,myHero)
			local WDamage = getDmg("W",Unit,myHero)
			local EDamage = getDmg("E",Unit,myHero)
			local HITDamage = getDmg("AD",Unit,myHero)
			local ONHITDamage = (SHEENSlot and getDmg("SHEEN",Unit,myHero) or 0)+(TRINITYSlot and getDmg("TRINITY",Unit,myHero) or 0)+(LICHBANESlot and getDmg("LICHBANE",Unit,myHero) or 0)
			local ONSPELLDamage = (LIANDRYSSlot and getDmg("LIANDRYS",Unit,myHero) or 0)+(BLACKFIRESlot and getDmg("BLACKFIRE",Unit,myHero) or 0)
			local IGNITEDamage = (IGNITESlot and getDmg("IGNITE",Unit,myHero) or 0)
			local DFGDamage = (DFGSlot and getDmg("DFG",Unit,myHero) or 0)
			local HXGDamage = (HXGSlot and getDmg("HXG",Unit,myHero) or 0)
			local LIANDRYSDamage = (LIANDRYSSlot and getDmg("LIANDRYS",Unit,myHero) or 0)
			local combo1 = HITDamage + ONHITDamage + ONSPELLDamage
			local combo2 = HITDamage + ONHITDamage + ONSPELLDamage
			local combo3 = HITDamage + ONHITDamage + ONSPELLDamage
			local mana = 0

			if QREADY then
				combo1 = combo1 + QDamage
				combo2 = combo2 + QDamage
				combo3 = combo3 + QDamage
				mana = mana + myHero:GetSpellData(_Q).mana
			end

			if WREADY then
				combo1 = combo1 + WDamage
				combo2 = combo2 + WDamage
				combo3 = combo3 + WDamage
				mana = mana + myHero:GetSpellData(_W).mana
			end

			if EREADY then
				combo1 = combo1 + EDamage
				combo2 = combo2 + EDamage
				combo3 = combo3 + EDamage
				mana = mana + myHero:GetSpellData(_E).mana
			end

			if DFGReady then
				combo2 = combo2 + DFGDamage
				combo3 = combo3 + DFGDamage
			end

			if HXGReady then
				combo2 = combo2 + HXGDamage
				combo3 = combo3 + HXGDamage
			end

			if IGNITEReady then
				combo3 = combo3 + IGNITEDamage
			end

			killable[i] = 1 -- the default value = harass

			if (combo3 >= Unit.health) and (myHero.mana >= mana) then -- all cooldowns needed
				killable[i] = 2
			end

			if (combo2 >= Unit.health) and (myHero.mana >= mana) then -- only spells and items needed
				killable[i] = 3
			end

			if (combo1 >= Unit.health) and (myHero.mana >= mana) then -- only spells needed
				killable[i] = 4
			end
	end
end
end

function UseUlti(Unit)
	local calcenemy = 1

	if ValidTarget(Unit) and AutoCarry.PluginMenu.aUlti and RREADY then
		for i=1, heroManager.iCount do
    		local Enemy = heroManager:GetHero(i)
    		if Enemy.charName == Unit.charName then
    			calcenemy = i
    		end
    	end

    	local EnemysInRange = CountEnemyHeroInRange()
		if EnemysInRange >= 2 or (myHero.health / myHero.maxHealth <= 0.5) or killable[calcenemy] == 2 or killable[calcenemy] == 3
			then CastSpell(_R)
		end
    end
end

function onChoiceFunction() -- our callback function for the ability leveling
	if myHero:GetSpellData(_Q).level < myHero:GetSpellData(_W).level then
		return 1
	else
		return 2
	end
end