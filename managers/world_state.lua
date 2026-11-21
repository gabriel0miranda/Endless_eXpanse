-- Estado persistente do mundo.
--
-- Tudo o que muda durante o jogo e precisa sobreviver a uma troca de sistema
-- (e, no futuro, a um save) fica aqui: relógio, sistema atual e, para cada
-- sistema visitado, a fase orbital e o mercado de cada landable.
--
-- Regras:
--   * data/*.lua é só leitura; o que muda em jogo vem para cá.
--   * Só dados simples (números, strings, tabelas). Nada de corpos do Box2D,
--     funções ou referências a entidades, para o estado poder ir direto para
--     um arquivo de save.
--   * Asteroides e NPCs anônimos não são guardados: são gerados de novo.
local WorldState = {}

WorldState.VERSION = 1

---@class WorldStateData
---@field version integer
---@field time number
---@field currentSystemId integer
---@field systems table<string, {landables: table<string, table>}>

---@type WorldStateData
local state = nil

-- Começa um mundo novo (novo jogo)
function WorldState.new(startingSystemId)
  state = {
    version         = WorldState.VERSION,
    time            = 0,  -- segundos de jogo desde o início
    currentSystemId = startingSystemId,
    systems         = {},
  }
end

-- Tabela crua do estado, para o save
function WorldState.get()
  return state
end

-- Substitui o estado inteiro (carregar um save)
function WorldState.load(data)
  state = data
end

function WorldState.time()
  return state and state.time or 0
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

return WorldState
