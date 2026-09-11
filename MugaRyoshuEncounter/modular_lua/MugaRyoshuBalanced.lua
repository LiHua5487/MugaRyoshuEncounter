-- 无我良秀（平衡版）
-- MSS handles combat events; the bridge supplies native enemy patterns from shared data.

local SELF = "SelfCore"

local TRACE = 880962101
local SMEAR = 880962102
local SPLASH = 880962103
local ERASE = 880962104
local HEAVENLY_KILL = 880962105
local STRONG = 880962106
local BLANK = 880962107

local SELFLESSNESS = "MugaRyoshuBalancedSelflessness"
local HEAVENLY_STAR = "MugaRyoshuBalancedHeavenlyStar"
local CUT_THREAD = "MugaRyoshuBalancedCutThread"
local GUARDIAN = "MugaRyoshuGuardianResolve"

local D_PHASE = 88096210
local D_PHASE_START_ROUND = 88096211
local D_HITS_THIS_ROUND = 88096212
local D_EVADE_HEAL_ROUND = 88096213
local D_STRONG_TARGET_INST = 88096214
local D_STRONG_TARGET_ROUND = 88096215
local D_PHASE_PENDING = 88096216
local D_CUT_BONUS = 88096217
local D_DAMAGE_REDUCTION = 88096218
local D_LAST_SPECIAL_ROUND = 88096219
local D_SPECIAL_SPEED_ROUND = 88096231

local function number(value, fallback)
    local result = tonumber(value)
    if result == nil then return fallback or 0 end
    return result
end

local function data(key)
    return number(getdata(SELF, key), 0)
end

local function put(key, value)
    setdata(SELF, key, value)
end

local function stack(unit, keyword)
    local value = number(getbuff(unit, keyword, "stack"), 0)
    if value < 0 then return 0 end
    return value
end

local function round_number()
    return number(getround(), 1)
end

local function find_strong_target()
    local units = selecttargets("EnemyNoCores99")
    local best = nil
    local best_max_hp = -1
    if type(units) ~= "table" then return nil end

    for _, unit in ipairs(units) do
        if stack(unit, CUT_THREAD) >= 15 then
            local max_hp = number(gethp(unit, "max"), 0)
            if max_hp > best_max_hp then
                best = unit
                best_max_hp = max_hp
            end
        end
    end
    return best
end

function muga_guardian_refresh()
    mugaguardian("prepare")
    -- This script belongs to the boss: its enemies are the player units.
    local units = selecttargets("EnemyNoCores99")
    if type(units) ~= "table" then return end
    for _, unit in ipairs(units) do
        if stack(unit, GUARDIAN) < 1 then
            buff(unit, GUARDIAN, 1, 0, 0)
        end
        mugaguardian("granted", unit, #units)
    end
end

function muga_start()
    mugaguardian("reset")
    muga_guardian_refresh()
    put(D_PHASE, 1)
    put(D_PHASE_START_ROUND, 0)
    put(D_HITS_THIS_ROUND, 0)
    put(D_EVADE_HEAL_ROUND, -1)
    put(D_STRONG_TARGET_INST, 0)
    put(D_STRONG_TARGET_ROUND, 0)
    put(D_PHASE_PENDING, 0)
    put(D_CUT_BONUS, 0)
    put(D_LAST_SPECIAL_ROUND, 0)
    put(D_SPECIAL_SPEED_ROUND, -1)
    put(88096232, 0) -- status caps activate on the first HP change below 900

    muga_pattern()
end

function muga_abyss_start()
    local mp = number(getsp(SELF), 0)
    if mp ~= -44 then changesp(SELF, -44) end
    buff(SELF, HEAVENLY_STAR, 1, 0, 0)
    passivereveal(SELF, 880962002)
end

function muga_limit_sanity()
    local mp = number(getsp(SELF), -44)
    local maximum = data(D_PHASE) >= 2 and 0 or 45
    local limited = math.max(-44, math.min(maximum, mp))
    -- MSS changesp sets an absolute value. Only correct an out-of-range value,
    -- so a nested AfterChangeSanity event terminates immediately.
    if limited ~= mp then changesp(SELF, limited) end
end

function muga_round_start()
    local entered_phase_two = false
    if data(D_PHASE) == 1 and data(D_PHASE_PENDING) == 1 then
        put(D_PHASE, 2)
        put(D_PHASE_START_ROUND, round_number())
        put(D_PHASE_PENDING, 0)
        entered_phase_two = true

    end

    muga_limit_sanity()

    put(D_HITS_THIS_ROUND, 0)
    buff(SELF, SELFLESSNESS, round_number(), 0, 0)
    passivereveal(SELF, 880962001)

    if entered_phase_two then
        mugacleanse()
        local current = stack(SELF, SELFLESSNESS)
        if current < 50 then buff(SELF, SELFLESSNESS, 50 - current, 0, 0) end
        passivereveal(SELF, 880962002)
    end

    put(D_CUT_BONUS, math.min(4, math.floor(stack(SELF, SELFLESSNESS) / 25)))
    muga_guardian_refresh()

    muga_pattern()
end

function muga_pattern()
    local round = round_number()
    local phase = data(D_PHASE)
    local skills = {}

    if round <= 1 then
        skills = { SPLASH, SMEAR, SMEAR, SMEAR, TRACE, BLANK }
    elseif phase < 2 then
        local mp = number(getsp(SELF), -44)
        if mp >= 20 then
            skills = { ERASE, SPLASH, SPLASH, SMEAR, SMEAR, SMEAR, BLANK }
        else
            skills = { ERASE, SPLASH, SMEAR, SMEAR, SMEAR, TRACE, BLANK }
        end
    else
        local phase_start = data(D_PHASE_START_ROUND)
        local last_special = math.max(phase_start - 1, data(D_LAST_SPECIAL_ROUND))
        if phase_start > 0 and (round == phase_start or round - last_special >= 4) then
            skills = { HEAVENLY_KILL, BLANK, BLANK, BLANK }
        else
            skills = { ERASE, SPLASH, SMEAR, SMEAR, SMEAR, TRACE, BLANK }
        end
    end

    local target = find_strong_target()
    if target ~= nil then
        skills = { STRONG, BLANK, BLANK, BLANK }
        local raw_inst = string.gsub(target, "inst", "")
        put(D_STRONG_TARGET_INST, number(raw_inst, 0))
        put(D_STRONG_TARGET_ROUND, round)
    else
        put(D_STRONG_TARGET_INST, 0)
        put(D_STRONG_TARGET_ROUND, 0)
    end

    -- The native pattern bridge reads these before enemy slots are created.
    put(88096220, #skills)
    for index, skill in ipairs(skills) do put(88096220 + index, skill) end

    if (skills[1] == HEAVENLY_KILL or skills[1] == STRONG)
        and data(D_SPECIAL_SPEED_ROUND) ~= round then
        put(D_SPECIAL_SPEED_ROUND, round)
        addability(SELF, "MinSpeedAdder", 10, 1, 0)
        addability(SELF, "MaxSpeedAdder", 10, 1, 0)
        refreshspeed(SELF)
    end
end

function muga_special_used()
    put(D_LAST_SPECIAL_ROUND, round_number())
end

function muga_trace_win()
    -- Skill actions belong to the abnormality part; SP belongs to its core.
    healsp(SELF, 12)
    dmgmult(-80)
end

function muga_on_hit()
    local gained = data(D_HITS_THIS_ROUND)
    if gained < 5 then
        buff(SELF, SELFLESSNESS, 1, 0, 0)
        put(D_HITS_THIS_ROUND, gained + 1)
        passivereveal(SELF, 880962001)
    end

end

function muga_outgoing_damage()
    local reduction = math.max(0, 80 - stack(SELF, SELFLESSNESS))
    dmgmult(-reduction)
    if reduction > 0 then passivereveal(SELF, 880962001) end
end

function muga_last_coin_hit()
    if number(mugacanapplycut(), 0) == 0 then return end
    if number(coinindex("isLastCoin"), 0) == 1 then
        muga_give_cutthread(1)
        passivereveal(SELF, 880962003)
    end
end

function muga_give_cutthread(base_stack)
    if number(mugacanapplycut(), 0) == 0 then return end
    local bonus = data(D_CUT_BONUS)
    buff("Target", CUT_THREAD, number(base_stack, 0) + bonus, 0, 0)
end

function muga_clash_start()
    put(88096230, 0)
end

function muga_repeated_clash()
    local previous = data(88096230)
    put(88096230, previous + 1)
    if previous >= 10 then
        clash(previous - 9)
        passivereveal(SELF, 880962003)
    end
end

function muga_blank_evade()
    local round = round_number()
    if data(D_EVADE_HEAL_ROUND) ~= round then
        put(D_EVADE_HEAL_ROUND, round)
        healsp(SELF, 5)
    end
end

function muga_prepare_damage_reduction()
    -- MSS BeforeWhenHit: Self is the attacker, Target is the struck part.
    local reduction = math.min(50, math.floor(stack("TargetCore", SELFLESSNESS) / 2)
        + stack("SelfCore", CUT_THREAD))
    setdata("Target", D_DAMAGE_REDUCTION, reduction)
end

function muga_reduce_attack_damage()
    -- This passive is on the struck part, so the reduction is applied once.
    local original_damage = math.max(0, number(getdmg(), 0))
    local final_damage = original_damage

    if number(ctdsource(), -1) == 0 then
        local reduction = number(getdata("Self", D_DAMAGE_REDUCTION), 0)
        if reduction > 0 then
            final_damage = math.floor(final_damage * (100 - reduction) / 100)
        end
        passivereveal(SELF, 880962003)
    end

    -- Keep the 900 HP floor until this round ends naturally.
    -- Only mark phase two for the next RoundStart; do not stop any actions.
    local phase_pending = false
    if data(D_PHASE) == 1 then
        local hp = number(gethp(SELF, "current"), 0)
        local allowed = math.max(0, hp - 900)
        if final_damage >= allowed and original_damage > 0 and hp >= 900 and data(D_PHASE_PENDING) == 0 then
            final_damage = allowed
            phase_pending = true
        elseif final_damage > allowed then
            final_damage = allowed
        end
    end

    if final_damage ~= original_damage then setdmgtaken(final_damage) end
    if phase_pending then put(D_PHASE_PENDING, 1) end
end

function muga_convert_sanity_damage()
    -- The consequence reads MSS's current BeforeChangeSanity value, consumes
    -- it, then runs the copied 40001502 absolute-damage + trigger-log path.
    mugafixeddmg(SELF)
end

function muga_immortal()
    if data(D_PHASE) == 1 then setimmortal(1) else setimmortal(0) end
end

-- Same max-buff adder path as native PassiveAbility_501911 (99-69 / 99-89).
-- The adder rules belong only to the core: parts inherit its contribution.
function muga_status_caps()
    if data(88096232) == 0 then
        if number(gethp(SELF, "current"), 900) >= 900 then return end
        put(88096232, 1)
    end
    -- Refresh existing current/queued BuffInfo through the native model.
    -- New buffs also query these limits when they are constructed.
    updatemaxbuf("SelfCore+SelfParts")
end
