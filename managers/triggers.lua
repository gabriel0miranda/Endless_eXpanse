-- Gatilhos de mensagem (data/triggers.lua).
--
-- Um estado do jogo chama Triggers.fire(evento, contexto, continuar) num
-- ponto em que o jogador fez uma ação. Os gatilhos daquele evento cujas
-- condições valem aparecem em sequência no DialogueUI; depois da última
-- mensagem, `continuar` é chamado. Sem gatilho, `continuar` roda na hora.
--
-- As condições hoje são cenário inicial, landable, sistema e chance. As
-- missões vão entrar como mais uma condição, e o disparo poderá iniciar uma.
local Triggers = {}

local function playerStart()
  local player = config.Entities.getByTag("player")[1]
  return player and player.startingScenario
end

-- O gatilho vale no contexto ctx = { landable = nome }?
local function matches(id, trigger, ctx)
  local cond = trigger.conditions or {}
  if trigger.once and config.WorldState.triggerCount(id) > 0 then return false end
  if cond.start and config.Starts[cond.start] ~= playerStart() then return false end
  if cond.landable and cond.landable ~= ctx.landable then return false end
  if cond.system and cond.system ~= config.WorldState.currentSystemId() then return false end
  if cond.chance and love.math.random() >= cond.chance then return false end
  return true
end

-- Gatilhos do evento que valem agora, em ordem de id (ordem estável), como
-- { id = chave, trigger = dados }
function Triggers.matching(event, ctx)
  local ids = {}
  for id, trigger in pairs(config.TriggerData) do
    if trigger.event == event then ids[#ids + 1] = id end
  end
  table.sort(ids)
  local list = {}
  for _, id in ipairs(ids) do
    local trigger = config.TriggerData[id]
    if matches(id, trigger, ctx or {}) then list[#list + 1] = { id = id, trigger = trigger } end
  end
  return list
end

-- Troca `{key:action}` no texto pela tecla ligada à action (ver input.lua),
-- para a mensagem acompanhar o remapeamento de controles
function Triggers.format(text)
  return (text:gsub("{key:([%w_]+)}", function(action)
    local key = config.Input.keyFor and config.Input.keyFor(action)
    return key and key:upper() or "?"
  end))
end

-- Mostra os gatilhos do evento um depois do outro e chama `continue` no fim.
-- Um gatilho conta como disparado quando o jogador fecha a mensagem.
-- Devolve true se alguma mensagem apareceu.
function Triggers.fire(event, ctx, continue)
  local queue = Triggers.matching(event, ctx)
  local i = 0
  local function nextMessage()
    i = i + 1
    local entry = queue[i]
    if not entry then
      if continue then continue() end
      return
    end
    config.DialogueUI.open({
      speaker   = entry.trigger.speaker,
      text      = Triggers.format(entry.trigger.text),
      onConfirm = function()
        config.WorldState.markTrigger(entry.id)
        nextMessage()
      end,
    })
  end
  nextMessage()
  return #queue > 0
end

return Triggers
