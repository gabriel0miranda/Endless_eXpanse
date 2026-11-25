-- Missões: trabalhos do bar, missões de história e reputação.
--
-- Uma *missão* é um registro de dados simples guardado no WorldState (e no
-- save). Uma *oferta* é uma missão ainda não aceita, gerada para o bar de um
-- landable e guardada até o fim do período de renovação. Ao aceitar, a
-- oferta vira missão ativa. Uma missão ativa termina de três jeitos:
--   cumprida   o jogador chega ao destino com o que a missão pede
--   falha      o prazo vence ou o jogador desiste
--   (história) as missões de história só terminam cumpridas
-- Os modelos, recompensas e prazos ficam em data/missions.lua.
--
-- As funções devolvem mensagens { speaker, text } em vez de mostrá-las, para
-- quem chama decidir entre caixa de diálogo (pousado) e feed do HUD (em voo).
local Missions = {}

local HOUR = 3600

local function data() return config.MissionData end
local function state() return config.WorldState.missions() end

local function dayLength()
  return config.CalendarData.hoursPerDay * HOUR
end

local function randomInt(range)
  return love.math.random(range[1], range[2])
end

local function randomFloat(range)
  return range[1] + love.math.random() * (range[2] - range[1])
end

local function landableName(key)
  local l = config.Landables[key]
  return l and l.name or key
end

local function systemName(id)
  local s = config.Systems[id]
  return s and s.name or ("sistema " .. tostring(id))
end

local function itemName(key)
  local i = config.Items[key]
  return i and i.name or key
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

-- Facção de um landable: o campo `faction` dele ou a facção de maior peso
-- na população do sistema (data/systems.lua). Sem nenhuma, "Independentes".
function Missions.landableFaction(systemId, landableKey)
  local l = config.Landables[landableKey]
  if l and l.faction then return l.faction end
  local sys = config.Systems[systemId]
  local weights = sys and sys.population and sys.population.categoryWeights
    and sys.population.categoryWeights.faction or {}
  local best, bestWeight
  for _, faction in ipairs(sortedKeys(weights)) do
    if not bestWeight or weights[faction] > bestWeight then
      best, bestWeight = faction, weights[faction]
    end
  end
  return best or "Independentes"
end

-- Distância em saltos de `from` a cada sistema alcançável em até
-- `maxJumps`, pelo grafo completo de buracos de minhoca (o contratante
-- conhece rotas que o jogador ainda não conhece)
function Missions.systemsWithin(from, maxJumps)
  local dist = { [from] = 0 }
  local queue, head = { from }, 1
  while queue[head] do
    local id = queue[head]
    head = head + 1
    if dist[id] < maxJumps then
      for _, w in ipairs(config.Systems[id].wormholes or {}) do
        local to = w.toSystem
        if to and config.Systems[to] and dist[to] == nil then
          dist[to] = dist[id] + 1
          queue[#queue + 1] = to
        end
      end
    end
  end
  return dist
end

-- Troca {chave} pelo valor em `vars`
function Missions.format(text, vars)
  return (text:gsub("{(%w+)}", function(key)
    local v = vars[key]
    return v ~= nil and tostring(v) or "{" .. key .. "}"
  end))
end

-- Indústrias do landable: { insumos = {item=true}, produtos = {item=true} }
local function industryItems(landableKey)
  local inputs, outputs = {}, {}
  local market = config.Landables[landableKey] and config.Landables[landableKey].market
  for industry in pairs(market and market.industries or {}) do
    local def = config.Industries[industry]
    local recipes = def and (def.recipes or { def }) or {}
    for _, r in ipairs(recipes) do
      for item in pairs(r.inputs or {}) do inputs[item] = true end
      for item in pairs(r.outputs or {}) do outputs[item] = true end
    end
  end
  return inputs, outputs
end

local function pick(list)
  if #list == 0 then return nil end
  return list[love.math.random(1, #list)]
end

-- Itens comuns de carga, para quando o landable não produz nada
local function goodItems()
  local list = {}
  for _, key in ipairs(sortedKeys(config.Items)) do
    if config.Items[key].category == "good" then list[#list + 1] = key end
  end
  return list
end

-- Landables de outro lugar até maxJumps: { { system, landable, jumps }, ... }
local function destinations(systemId, landableKey)
  local list = {}
  local dist = Missions.systemsWithin(systemId, data().offers.maxJumps)
  for _, id in ipairs(sortedKeys(dist)) do
    for _, key in ipairs(config.Systems[id].landables or {}) do
      if not (id == systemId and key == landableKey) then
        list[#list + 1] = { system = id, landable = key, jumps = dist[id] }
      end
    end
  end
  return list
end

-- Sistemas com piratas até maxJumps
local function pirateSystems(systemId)
  local list = {}
  local dist = Missions.systemsWithin(systemId, data().offers.maxJumps)
  for _, id in ipairs(sortedKeys(dist)) do
    local weights = config.Systems[id].population and config.Systems[id].population.weights or {}
    if (weights.Pirate or 0) > 0 then list[#list + 1] = id end
  end
  return list
end

-- Cria uma oferta do tipo `kind`; nil se o tipo não cabe neste landable.
-- ctx = { system, landable, now, capacity (espaço livre no porão da nave ativa) }
local function makeOffer(kind, ctx)
  local job = data().jobs[kind]
  local o = {
    kind    = kind,
    faction = Missions.landableFaction(ctx.system, ctx.landable),
    origin  = { system = ctx.system, landable = ctx.landable },
  }
  local vars = { origin = landableName(ctx.landable) }

  if kind == "delivery" or kind == "passengers" then
    local dest = pick(destinations(ctx.system, ctx.landable))
    if not dest then return nil end
    o.dest = { system = dest.system, landable = dest.landable }
    vars.dest, vars.destSystem = landableName(dest.landable), systemName(dest.system)
    local days = job.deadline.baseDays + job.deadline.perJumpDays * dest.jumps
    o.deadline = ctx.now + days * dayLength()
    if kind == "delivery" then
      local _, outputs = industryItems(ctx.landable)
      local item = pick(sortedKeys(outputs)) or pick(goodItems())
      local volume = config.Items[item].volume or 1
      local quantity = math.floor(ctx.capacity * randomFloat(job.cargoFraction) / volume)
      if quantity < 1 then return nil end  -- porão cheio: sem entrega hoje
      o.item, o.quantity = item, quantity
      o.reward = math.floor(job.reward.base + job.reward.perJump * dest.jumps
        + job.reward.perVolume * quantity * volume)
      vars.item, vars.quantity = itemName(item), quantity
    else
      o.passengers = randomInt(job.passengers)
      o.reward = job.reward.base + job.reward.perJump * dest.jumps
        + job.reward.perPassenger * o.passengers
      vars.passengers = o.passengers
    end
  elseif kind == "procure" then
    local inputs = industryItems(ctx.landable)
    local item = pick(sortedKeys(inputs))
    if not item then return nil end
    o.item, o.quantity = item, randomInt(job.quantity)
    o.dest = { system = ctx.system, landable = ctx.landable }
    o.deadline = ctx.now + job.deadline.days * dayLength()
    o.reward = math.floor(o.quantity * (config.Items[item].basePrice or 10) * job.markup)
    vars.item, vars.quantity = itemName(item), o.quantity
  elseif kind == "bounty" then
    local target = pick(pirateSystems(ctx.system))
    if not target then return nil end
    o.system, o.count, o.kills = target, randomInt(job.count), 0
    o.dest = { system = ctx.system, landable = ctx.landable }
    o.deadline = ctx.now + job.deadline.days * dayLength()
    o.reward = job.reward.perKill * o.count
    vars.system, vars.count = systemName(target), o.count
  end

  vars.reward = o.reward
  vars.deadline = config.Calendar.format(o.deadline)
  o.title = Missions.format(job.title, vars)
  o.text  = Missions.format(job.text, vars)
  return o
end

-- Sorteia um tipo de trabalho pelos pesos de data/missions.lua
local function pickKind()
  local kinds, total = sortedKeys(data().jobs), 0
  for _, k in ipairs(kinds) do total = total + data().jobs[k].weight end
  local r = love.math.random() * total
  for _, k in ipairs(kinds) do
    r = r - data().jobs[k].weight
    if r <= 0 then return k end
  end
  return kinds[#kinds]
end

-- Gera as ofertas de um bar (sem guardar)
function Missions.generateOffers(ctx)
  local list, tries = {}, 0
  local wanted = randomInt({ data().offers.min, data().offers.max })
  while #list < wanted and tries < wanted * 4 do
    tries = tries + 1
    local offer = makeOffer(pickKind(), ctx)
    if offer then list[#list + 1] = offer end
  end
  return list
end

local function offerKey(systemId, landableKey)
  return tostring(systemId) .. ":" .. landableKey
end

-- Ofertas do bar do landable; renovadas a cada `refreshDays` dias de jogo.
-- capacity: espaço livre no porão da nave ativa, para dimensionar as entregas.
function Missions.offers(systemId, landableKey, capacity)
  local now = config.Calendar.now()
  local period = math.floor(now / (dayLength() * data().offers.refreshDays))
  local key = offerKey(systemId, landableKey)
  local entry = state().offers[key]
  if not entry or entry.period ~= period then
    entry = {
      period = period,
      list = Missions.generateOffers({
        system = systemId, landable = landableKey, now = now, capacity = capacity or 100,
      }),
    }
    state().offers[key] = entry
  end
  return entry.list
end

function Missions.active()
  return state().active
end

-- Beliches da nave ainda livres
function Missions.freeBunks(ship)
  local def = config.Ships[ship.type] or {}
  local used = 0
  for _, m in ipairs(Missions.active()) do
    if m.kind == "passengers" then used = used + m.passengers end
  end
  return (def.bunks or 0) - used
end

-- Aceita a oferta `index` do bar. ship: nave ativa (entidade, com inventory).
-- Devolve ok, mensagem de erro.
function Missions.accept(systemId, landableKey, index, ship)
  local list = state().offers[offerKey(systemId, landableKey)]
  list = list and list.list
  local offer = list and list[index]
  if not offer then return false, "Essa oferta não está mais disponível." end

  if offer.kind == "delivery" then
    local volume = (config.Items[offer.item].volume or 1) * offer.quantity
    if ship.inventory.capacity - ship.inventory.capacityUsed < volume then
      return false, "Não há espaço no porão para a carga."
    end
    ship.inventory:add(offer.item, offer.quantity)
  elseif offer.kind == "passengers" then
    if Missions.freeBunks(ship) < offer.passengers then
      return false, "Não há beliches livres para todos os passageiros."
    end
  end

  table.remove(list, index)
  offer.id = state().nextId
  state().nextId = state().nextId + 1
  table.insert(state().active, offer)
  -- O destino passa a constar no mapa da galáxia
  local target = offer.kind == "bounty" and offer.system or offer.dest.system
  if not config.WorldState.isVisited(target) then config.WorldState.reveal(target) end
  return true
end

-- Inicia uma missão de história de data/missions.lua (uma vez só)
function Missions.startStory(key)
  local def = data().story[key]
  if not def then return false end
  for _, m in ipairs(Missions.active()) do
    if m.story == key then return false end
  end
  if (state().done or {})[key] then return false end
  local m = {
    id = state().nextId, kind = "story", story = key,
    title = def.title, text = def.text, objective = def.objective,
    system = def.system, reward = def.reward or 0,
  }
  state().nextId = state().nextId + 1
  table.insert(state().active, m)
  if def.system and not config.WorldState.isVisited(def.system) then
    config.WorldState.reveal(def.system)
  end
  return true
end

local function removeActive(id)
  for i, m in ipairs(Missions.active()) do
    if m.id == id then return table.remove(Missions.active(), i) end
  end
end

local function player()
  return config.Entities.getByTag("player")[1]
end

local function complete(m)
  removeActive(m.id)
  if m.story then
    state().done = state().done or {}
    state().done[m.story] = true
  end
  local p = player()
  if p and m.reward and m.reward > 0 then p.credits.amount = p.credits.amount + m.reward end
  if m.faction then
    local rep = data().reputation
    config.WorldState.addReputation(m.faction, m.kind == "bounty" and rep.bounty or rep.success)
  end
  local text = m.title .. ": missão cumprida."
  if m.reward and m.reward > 0 then text = text .. " Você recebeu " .. m.reward .. " cr." end
  return { speaker = "Missão cumprida", text = text }
end

local function fail(m, reason)
  removeActive(m.id)
  if m.faction then
    config.WorldState.addReputation(m.faction, data().reputation.failure)
  end
  local text = m.title .. ": " .. reason
  if m.faction then text = text .. " Sua reputação com " .. m.faction .. " caiu." end
  return { speaker = "Missão falhou", text = text }
end

-- Desiste da missão `id` (conta como falha). Missões de história não podem
-- ser abandonadas.
function Missions.abandon(id)
  for _, m in ipairs(Missions.active()) do
    if m.id == id and not m.story then
      return fail(m, "você desistiu.")
    end
  end
end

-- Falha as missões com prazo vencido em `now`. Devolve as mensagens.
function Missions.checkDeadlines(now)
  local messages, expired = {}, {}
  for _, m in ipairs(Missions.active()) do
    if m.deadline and now > m.deadline then expired[#expired + 1] = m end
  end
  for _, m in ipairs(expired) do
    messages[#messages + 1] = fail(m, "o prazo venceu.")
  end
  return messages
end

-- Pouso em `landableKey` do sistema `systemId`. Confere prazos e entrega o
-- que a nave traz. Devolve as mensagens, em ordem.
function Missions.onLand(systemId, landableKey, ship)
  local messages = Missions.checkDeadlines(config.Calendar.now())
  local done = {}
  for _, m in ipairs(Missions.active()) do
    local here = m.dest and m.dest.system == systemId and m.dest.landable == landableKey
    if here then
      if m.kind == "passengers" then
        done[#done + 1] = m
      elseif m.kind == "bounty" then
        if m.kills >= m.count then done[#done + 1] = m end
      elseif m.kind == "delivery" or m.kind == "procure" then
        local have = ship.inventory.items[m.item] or 0
        if have >= m.quantity then
          ship.inventory:remove(m.item, m.quantity)
          done[#done + 1] = m
        else
          messages[#messages + 1] = { speaker = m.title, text = string.format(
            "Faltam %d de %s no porão para concluir a missão.", m.quantity - have, itemName(m.item)) }
        end
      end
    end
  end
  for _, m in ipairs(done) do messages[#messages + 1] = complete(m) end
  return messages
end

-- Entrada num sistema: cumpre as missões de história "reach"
function Missions.onSystemEntered(systemId)
  local messages, done = {}, {}
  for _, m in ipairs(Missions.active()) do
    if m.objective == "reach" and m.system == systemId then done[#done + 1] = m end
  end
  for _, m in ipairs(done) do messages[#messages + 1] = complete(m) end
  return messages
end

-- Facção da nave: o perfil fica no NPC dono dela (entities/npc.lua), não
-- na entidade da nave
local function shipFaction(ship)
  if ship.profile then return ship.profile.faction end
  for _, npc in ipairs(config.Entities.getByTag("npc")) do
    if npc.ship == ship then return npc.profile and npc.profile.faction end
  end
end

-- Nave destruída; `killer` é a nave que deu o último dano. Conta piratas
-- destruídos pela nave ativa no sistema da caça. Devolve as mensagens.
function Missions.onShipDestroyed(ship, killer)
  local messages = {}
  if not config.WorldState.get() then return messages end
  if not (killer and killer.isFlagShip) then return messages end
  if shipFaction(ship) ~= "Pirate" then return messages end
  local here = config.WorldState.currentSystemId()
  for _, m in ipairs(Missions.active()) do
    if m.kind == "bounty" and m.system == here and m.kills < m.count then
      m.kills = m.kills + 1
      local text = string.format("%s: %d de %d piratas.", m.title, m.kills, m.count)
      if m.kills >= m.count then
        text = text .. " Volte a " .. landableName(m.dest.landable) .. " para receber."
      end
      messages[#messages + 1] = { speaker = "Missão", text = text }
    end
  end
  return messages
end

-- Texto curto do objetivo, para o diário de missões
function Missions.objectiveText(m)
  if m.kind == "delivery" then
    return string.format("Levar %d de %s até %s (%s).", m.quantity, itemName(m.item),
      landableName(m.dest.landable), systemName(m.dest.system))
  elseif m.kind == "passengers" then
    return string.format("Levar %d passageiro(s) até %s (%s).", m.passengers,
      landableName(m.dest.landable), systemName(m.dest.system))
  elseif m.kind == "procure" then
    return string.format("Trazer %d de %s para %s (%s).", m.quantity, itemName(m.item),
      landableName(m.dest.landable), systemName(m.dest.system))
  elseif m.kind == "bounty" then
    if m.kills >= m.count then
      return string.format("Voltar a %s (%s) para receber.", landableName(m.dest.landable), systemName(m.dest.system))
    end
    return string.format("Destruir piratas em %s: %d de %d.", systemName(m.system), m.kills, m.count)
  elseif m.objective == "reach" then
    return "Chegar ao sistema " .. systemName(m.system) .. "."
  end
  return ""
end

-- Sistema para onde a missão manda o jogador agora (para o mapa)
function Missions.targetSystem(m)
  if m.kind == "bounty" and m.kills < m.count then return m.system end
  if m.dest then return m.dest.system end
  return m.system
end

-- Sistemas-alvo das missões ativas: { [id] = true }
function Missions.targetSystems()
  local set = {}
  for _, m in ipairs(Missions.active()) do
    local id = Missions.targetSystem(m)
    if id then set[id] = true end
  end
  return set
end

return Missions
