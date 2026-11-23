-- Navegação entre sistemas: o que o jogador conhece da galáxia e as rotas
-- por buracos de minhoca. Lógica pura sobre data/systems.lua e o
-- WorldState; o desenho fica em ui/galaxy_map_ui.lua.
--
-- Conhecimento de um sistema, do mais completo para o mais vago:
--   "visited"   o jogador já esteve lá: nome, landables e buracos de minhoca
--   "neighbor"  ligado por buraco de minhoca a um sistema visitado
--   "revealed"  marcado no mapa sem visita, pelo cenário inicial (e, no futuro,
--               por missões ou rumores)
--   nil         desconhecido: não aparece no mapa
-- Um buraco de minhoca só é conhecido a partir de um sistema visitado.
local Navigation = {}

local function systems()
  return config.Systems
end

-- Ids dos sistemas ligados por buraco de minhoca a `id`
function Navigation.neighbors(id)
  local list = {}
  local sys = systems()[id]
  for _, w in ipairs(sys and sys.wormholes or {}) do
    if w.toSystem and systems()[w.toSystem] then list[#list + 1] = w.toSystem end
  end
  return list
end

function Navigation.knowledge(id)
  if config.WorldState.isVisited(id) then return "visited" end
  for otherId in pairs(systems()) do
    if config.WorldState.isVisited(otherId) then
      for _, to in ipairs(Navigation.neighbors(otherId)) do
        if to == id then return "neighbor" end
      end
    end
  end
  if config.WorldState.isRevealed(id) then return "revealed" end
  return nil
end

-- Buracos de minhoca conhecidos, sem repetir o par: { { from, to }, ... }
function Navigation.knownLinks()
  local links, seen = {}, {}
  local ids = {}
  for id in pairs(systems()) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    if config.WorldState.isVisited(id) then
      for _, to in ipairs(Navigation.neighbors(id)) do
        local a, b = math.min(id, to), math.max(id, to)
        local key = a .. "-" .. b
        if not seen[key] then
          seen[key] = true
          links[#links + 1] = { from = id, to = to }
        end
      end
    end
  end
  return links
end

-- Caminho mais curto em saltos de `from` até `to` pelos buracos de minhoca
-- conhecidos, por busca em largura. Devolve a lista de ids (com `from` e
-- `to`) ou nil se não há rota conhecida.
function Navigation.route(from, to)
  if from == to then return { from } end
  local prev = { [from] = from }
  local queue, head = { from }, 1
  while queue[head] do
    local id = queue[head]
    head = head + 1
    -- Só se conhece a saída de um sistema já visitado
    if config.WorldState.isVisited(id) then
      for _, next in ipairs(Navigation.neighbors(id)) do
        if prev[next] == nil then
          prev[next] = id
          if next == to then
            local path = { to }
            while path[1] ~= from do table.insert(path, 1, prev[path[1]]) end
            return path
          end
          queue[#queue + 1] = next
        end
      end
    end
  end
  return nil
end

-- Nome do buraco de minhoca de `from` que leva a `to` (vizinhos diretos)
function Navigation.wormholeTo(from, to)
  for _, w in ipairs(systems()[from].wormholes or {}) do
    if w.toSystem == to then return w.name end
  end
  return nil
end

return Navigation
