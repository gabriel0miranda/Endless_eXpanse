-- Estado persistente do mundo.
--
-- Tudo o que muda durante o jogo e precisa sobreviver a uma troca de sistema
-- ou a um save fica aqui: relógio, data inicial, sistema atual e, para cada
-- sistema visitado, os asteroides e a fase orbital e o mercado de cada landable.
--
-- Regras:
--   * data/*.lua é só leitura; o que muda em jogo vem para cá.
--   * Só dados simples (números, strings, tabelas). Nada de corpos do Box2D,
--     funções ou referências a entidades, para o estado poder ir direto para
--     um arquivo de save.
--   * NPCs anônimos não são guardados: são gerados de novo a cada visita.
--   * Asteroides de um sistema só se renovam com o descanso
--     (WorldState.resetSystem). Mercados evoluem com o tempo
--     (systems/economy.lua) e nunca são sorteados de novo.
local WorldState = {}

WorldState.VERSION = 1

---@class WorldStateData
---@field version integer
---@field time number
---@field startDate number
---@field currentSystemId integer
---@field systems table<string, {landables: table<string, table>, asteroids: table[]|nil, storedAt: number|nil}>
---@field triggers table<string, integer>
---@field visited table<string, boolean>
---@field revealed table<string, boolean>

---@type WorldStateData
local state = nil

-- Começa um mundo novo (novo jogo). startDate: data inicial do cenário, em
-- segundos de jogo (ver managers/calendar.lua)
function WorldState.new(startingSystemId, startDate)
  state = {
    version         = WorldState.VERSION,
    time            = 0,  -- segundos de simulação desde o início
    startDate       = startDate or 0,
    currentSystemId = startingSystemId,
    systems         = {},
    triggers        = {},  -- id do gatilho → quantas vezes disparou
    visited         = { [tostring(startingSystemId)] = true },
    revealed        = {},  -- sistemas marcados no mapa sem visita
    missions        = WorldState.emptyMissions(),
    reputation      = {},  -- facção → pontos (systems/missions.lua)
  }
end

-- Missões (systems/missions.lua): ativas, ofertas dos bares, missões de
-- história já cumpridas e contador de ids
function WorldState.emptyMissions()
  return { active = {}, offers = {}, done = {}, nextId = 1 }
end

-- Tabela crua do estado, para o save
function WorldState.get()
  return state
end

-- Substitui o estado inteiro (carregar um save)
function WorldState.load(data)
  state = data
  state.startDate = state.startDate or 0  -- saves anteriores ao calendário
  state.triggers  = state.triggers or {}  -- saves anteriores aos gatilhos
  state.revealed  = state.revealed or {}  -- saves anteriores ao mapa
  state.missions  = state.missions or WorldState.emptyMissions()  -- saves anteriores às missões
  state.reputation = state.reputation or {}
  if not state.visited then
    -- Saves anteriores ao mapa: todo sistema com registro foi visitado
    state.visited = { [tostring(state.currentSystemId)] = true }
    for key in pairs(state.systems) do state.visited[key] = true end
  end
end

function WorldState.time()
  return state and state.time or 0
end

function WorldState.startDate()
  return state and state.startDate or 0
end

-- Avança o relógio do mundo; chamado a cada passo da simulação em voo
function WorldState.advance(dt)
  if state then
    state.time = state.time + dt
  end
end

function WorldState.currentSystemId()
  return state and state.currentSystemId
end

function WorldState.setCurrentSystem(systemId)
  state.currentSystemId = systemId
  state.visited[tostring(systemId)] = true
end

-- Conhecimento do mapa da galáxia (systems/navigation.lua)
function WorldState.isVisited(systemId)
  return state ~= nil and state.visited[tostring(systemId)] == true
end

-- Sistema marcado no mapa da galáxia sem ter sido visitado
function WorldState.reveal(systemId)
  state.revealed[tostring(systemId)] = true
end

function WorldState.isRevealed(systemId)
  return state ~= nil and state.revealed[tostring(systemId)] == true
end

-- Registro de um sistema; criado vazio na primeira visita
function WorldState.system(systemId)
  local key = tostring(systemId)  -- chave string para o save não confundir com array
  local sys = state.systems[key]
  if not sys then
    sys = { landables = {} }
    state.systems[key] = sys
  end
  return sys
end

-- Registro de um landable dentro de um sistema; nil se ainda não existe
function WorldState.landable(systemId, name)
  return WorldState.system(systemId).landables[name]
end

function WorldState.setLandable(systemId, name, record)
  WorldState.system(systemId).landables[name] = record
end

-- Gatilhos de mensagem (managers/triggers.lua)
function WorldState.triggerCount(id)
  return state and state.triggers[id] or 0
end

function WorldState.markTrigger(id)
  state.triggers[id] = WorldState.triggerCount(id) + 1
end

-- Tabela das missões: { active = {...}, offers = {...}, nextId = n }
function WorldState.missions()
  return state.missions
end

-- Reputação com uma facção; começa em 0
function WorldState.reputation(faction)
  return state and state.reputation[faction] or 0
end

function WorldState.addReputation(faction, delta)
  state.reputation[faction] = WorldState.reputation(faction) + delta
end

-- Todas as reputações, para a interface
function WorldState.reputations()
  return state and state.reputation or {}
end

-- Descanso: os asteroides do sistema voltam a ser gerados na próxima visita.
-- A fase orbital e o mercado dos landables são mantidos.
function WorldState.resetSystem(systemId)
  local sys = WorldState.system(systemId)
  sys.asteroids = nil
  sys.storedAt  = nil
end

return WorldState
