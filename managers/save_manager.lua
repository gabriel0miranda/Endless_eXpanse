-- Save e continue, sempre a partir de um pouso.
--
-- Só se salva com a nave capitânia pousada num landable (não num wormhole).
-- Assim o save não precisa guardar nada da física: ao carregar, o sistema é
-- montado de novo a partir do WorldState e a nave volta pousada no mesmo lugar.
--
-- O que o save guarda:
--   * o WorldState inteiro (relógio, data, sistema atual, mercados, órbitas,
--     asteroides);
--   * o jogador: nome, créditos, cenário inicial, onde está pousado e as
--     propriedades (naves, com armas e carga).
-- O que não guarda: hull, escudos e capacitores (voltam cheios) e NPCs
-- (gerados de novo). Os asteroides vão junto, dentro do WorldState.
local SaveManager = {}

SaveManager.VERSION = 1

local FILE = "save.lua"

-- Itens renomeados em data/items.lua: chave antiga → nova. Saves antigos
-- guardam a chave antiga em estoques, cargas e sortimentos.
SaveManager.ITEM_RENAMES = {
  ["Phosporus"] = "Phosphorus",
}

-- Troca, no lugar, as chaves e os valores de texto renomeados em toda a tabela
function SaveManager.renameItems(t, seen)
  local renameItems = SaveManager.renameItems
  seen = seen or {}
  if seen[t] then return end
  seen[t] = true
  local renamed = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      renameItems(v, seen)
    elseif type(v) == "string" and SaveManager.ITEM_RENAMES[v] then
      t[k] = SaveManager.ITEM_RENAMES[v]
    end
    if SaveManager.ITEM_RENAMES[k] then renamed[k] = SaveManager.ITEM_RENAMES[k] end
  end
  for old, new in pairs(renamed) do
    if t[new] == nil then t[new] = t[old] end
    t[old] = nil
  end
end

-- Descarta itens que não existem mais em data/items.lua (removidos do jogo
-- depois do save), para o save carregar em vez de quebrar no inventário.
-- Olha só onde o save guarda itens: estoque, flutuação e sortimento dos
-- mercados e carga das propriedades. Devolve a lista do que foi descartado.
function SaveManager.dropUnknownItems(data)
  local dropped = {}
  local function dropKeys(t, where)
    for item, value in pairs(t or {}) do
      if not config.Items[item] then
        t[item] = nil
        dropped[#dropped + 1] = where .. ": " .. tostring(item) .. " (" .. tostring(value) .. ")"
      end
    end
  end

  for systemId, sys in pairs(data.world and data.world.systems or {}) do
    for name, landable in pairs(sys.landables or {}) do
      local market = landable.market
      if market then
        local where = "sistema " .. systemId .. ", " .. name
        dropKeys(market.items, where)
        dropKeys(market.noise, where .. " (flutuação)")
        local kept = {}
        for _, entry in ipairs(market.assortment or {}) do
          if config.Items[entry.item] then
            kept[#kept + 1] = entry
          else
            dropped[#dropped + 1] = where .. " (sortimento): " .. tostring(entry.item)
          end
        end
        if market.assortment then market.assortment = kept end
      end
    end
  end
  for name, property in pairs(data.player and data.player.properties or {}) do
    dropKeys(property.cargo, "carga de " .. tostring(name))
  end

  table.sort(dropped)
  return dropped
end

local function player()
  return config.Entities.getByTag("player")[1]
end

local function flagShip()
  return config.Entities.with("isFlagShip")[1]
end

-- Chave do cenário em config.Starts; o jogador guarda a tabela, o save guarda o nome
local function startKey(start)
  for key, s in pairs(config.Starts) do
    if s == start then return key end
  end
end

-- A carga da nave capitânia vive no inventário da entidade; a propriedade só
-- recebe uma cópia quando o sistema é trocado. Antes de salvar, sincroniza.
local function syncFlagShipCargo(p, ship)
  local property = p.property.properties[ship.name]
  if property then
    property.cargo = ship.inventory.items
  end
end

function SaveManager.exists()
  return love.filesystem.getInfo(FILE) ~= nil
end

-- Só dá para salvar pousado num landable de verdade
function SaveManager.canSave()
  local ship = flagShip()
  return player() ~= nil and ship ~= nil and ship.landedAt ~= nil
    and ship.landedAt ~= false and not ship.landedAt.toSystem
end

-- Monta a tabela do save a partir do jogo em andamento
function SaveManager.snapshot()
  local p, ship = player(), flagShip()
  config.WorldManager.storeSystem()
  syncFlagShipCargo(p, ship)
  return {
    version = SaveManager.VERSION,
    savedAt = os.time(),
    world   = config.WorldState.get(),
    player  = {
      name       = p.name,
      credits    = p.credits.amount,
      start      = startKey(p.startingScenario),
      landedAt   = ship.landedAt.name,
      properties = p.property.properties,
    },
  }
end

-- Devolve true, ou false e o motivo
function SaveManager.save()
  if not SaveManager.canSave() then
    return false, "Só é possível salvar pousado"
  end
  local ok, text = pcall(config.Serialize.encode, SaveManager.snapshot())
  if not ok then
    print("[save] erro ao serializar: " .. tostring(text))
    return false, text
  end
  local written, err = love.filesystem.write(FILE, text)
  if not written then
    print("[save] erro ao gravar: " .. tostring(err))
    return false, err
  end
  print("[save] jogo salvo em " .. love.filesystem.getSaveDirectory() .. "/" .. FILE)
  return true
end

-- Monta o jogo a partir de uma tabela de save (sem trocar de estado)
function SaveManager.restore(data)
  if data.version ~= SaveManager.VERSION then
    return false, "Save de uma versão incompatível (" .. tostring(data.version) .. ")"
  end
  local start = config.Starts[data.player.start]
  if not start then
    return false, "Cenário inicial desconhecido: " .. tostring(data.player.start)
  end

  SaveManager.renameItems(data)
  for _, entry in ipairs(SaveManager.dropUnknownItems(data)) do
    print("[save] item inexistente descartado: " .. entry)
  end
  config.Entities.clear()
  config.WorldState.load(data.world)

  -- Jogador montado direto dos dados salvos (PlayerEntity parte do cenário inicial)
  config.Entities.create("player", {
    name             = data.player.name,
    property         = config.PropertyComponent(data.player.properties),
    credits          = config.CreditsComponent(data.player.credits),
    landedAt         = false,
    startingScenario = start,
  })

  config.WorldManager.loadSystem(config.WorldState.currentSystemId())

  -- Devolve a nave ao landable onde ela estava pousada
  if not config.WorldManager.placeLanded(data.player.landedAt) then
    return false, "Local de pouso não encontrado: " .. tostring(data.player.landedAt)
  end
  return true
end

-- Carrega o save do disco e entra no jogo, pousado. Devolve true, ou false e o motivo.
function SaveManager.load()
  local text = love.filesystem.read(FILE)
  if not text then return false, "Nenhum jogo salvo" end
  local data, err = config.Serialize.decode(text)
  if not data then return false, "Save corrompido: " .. tostring(err) end

  local ok, restoreErr = SaveManager.restore(data)
  if not ok then return false, restoreErr end

  -- playing.onEnter vê a nave pousada e passa direto para o estado landed
  config.GameState.switch("playing")
  return true
end

return SaveManager
