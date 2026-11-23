local WorldManager = {}

WorldManager.systems = {}
WorldManager.snapshot = nil

function WorldManager.freeze()
  WorldManager.snapshot = {}
  for _, e in ipairs(config.Entities.all) do
    if  e.rigidbody and e.rigidbody.body then
      local vx, vy = e.rigidbody.body:getLinearVelocity()
      table.insert(WorldManager.snapshot, {
        entity = e,
        x      = e.rigidbody.body:getX(),
        y      = e.rigidbody.body:getY(),
        vx     = vx,
        vy     = vy,
        angle  = e.rigidbody.body:getAngle(),
        av     = e.rigidbody.body:getAngularVelocity(),
      })
      e.rigidbody.body:setActive(false)
    end
  end
end

function WorldManager.unfreeze()
  if not WorldManager.snapshot then return end
  for _, s in ipairs(WorldManager.snapshot) do
    if s.entity.isFlagShip then
      local player = config.Entities.getByTag("player")[1]
      local currentCargo = s.entity.inventory.items

      for _, property in pairs(player.property.properties) do
        if property.ship and property.name == s.entity.name then
          property.cargo = currentCargo
        end
        if property.ship and property.flagShip then
          config.ShipEntity(s.entity.rigidbody.body:getX(), s.entity.rigidbody.body:getY(), player.name, true, property.name, property.type, s.entity.landedAt, property.weapons, property.cargo)
        end
      end
      config.Entities.remove(s.entity)
    end
    if s.entity.rigidbody and s.entity.rigidbody.body and not s.entity.rigidbody.body:isDestroyed() then
      s.entity.rigidbody.body:setPosition(s.x, s.y)
      s.entity.rigidbody.body:setLinearVelocity(s.vx, s.vy)
      s.entity.rigidbody.body:setAngle(s.angle)
      s.entity.rigidbody.body:setAngularVelocity(s.av)
      s.entity.rigidbody.body:setActive(true)
    end
  end
  WorldManager.snapshot = nil
end

-- Começa um jogo do zero a partir de um cenário de data/starts.lua: apaga as
-- entidades de um jogo anterior (o menu pode ser aberto em pleno voo) e cria
-- um WorldState novo. Chamar antes de criar o jogador.
function WorldManager.newGame(start)
  config.Entities.clear()
  config.WorldState.new(start.starting_systemId, config.Calendar.toSeconds(start.starting_date or {}))
  for _, systemId in ipairs(start.known_systems or {}) do
    config.WorldState.reveal(systemId)
  end
end

-- Registro de dados simples de um asteroide (ver entities/asteroid.lua)
local function asteroidRecord(a)
  local body = a.rigidbody.body
  local vx, vy = body:getLinearVelocity()
  return {
    x = body:getX(), y = body:getY(), vx = vx, vy = vy,
    angle = body:getAngle(), av = body:getAngularVelocity(),
    size = a.mineable.originalRadius, radius = a.sprite.shape:getRadius(),
    stage = a.mineable.stage, health = a.mineable.health, maxHealth = a.mineable.max_health,
  }
end

-- Gira os asteroides guardados em volta da estrela pelo tempo em que o
-- jogador esteve fora. Supõe órbita circular (como na geração), mantendo
-- raio e velocidade; é uma aproximação barata que dispensa simular o sistema.
local function advanceAsteroids(records, sys, elapsed)
  local rotated = {}
  for i, r in ipairs(records) do
    local dx, dy = r.x - (sys.starX or 0), r.y - (sys.starY or 0)
    local dist2 = dx * dx + dy * dy
    local omega = dist2 > 0 and (dx * r.vy - dy * r.vx) / dist2 or 0
    local c, s = math.cos(omega * elapsed), math.sin(omega * elapsed)
    local copy = {}
    for k, v in pairs(r) do copy[k] = v end
    copy.x  = (sys.starX or 0) + dx * c - dy * s
    copy.y  = (sys.starY or 0) + dx * s + dy * c
    copy.vx = r.vx * c - r.vy * s
    copy.vy = r.vx * s + r.vy * c
    rotated[i] = copy
  end
  return rotated
end

-- Copia para o WorldState o que mudou no sistema atual: mercados dos
-- landables e asteroides. Chamar antes de descarregar o sistema e antes de salvar.
function WorldManager.storeSystem()
  local systemId = config.WorldState.currentSystemId()
  if not systemId then return end
  for _, l in ipairs(config.Entities.getByTag("landable")) do
    local record = not l.wormhole and config.WorldState.landable(systemId, l.name)
    if record and l.market and l.market.generated and l.inventory then
      record.market = {
        items        = l.inventory.items,
        noise        = l.market.noise,
        updatedAt    = l.market.updatedAt,
        assortment   = l.market.assortment,
        assortmentAt = l.market.assortmentAt,
      }
    end
  end

  -- Sem estrela, o sistema não foi montado (jogo novo): não há o que guardar
  if #config.Entities.getByTag("star") == 0 then return end
  local asteroids = {}
  for _, a in ipairs(config.Entities.getByTag("asteroid")) do
    if a.rigidbody and a.rigidbody.body and not a.rigidbody.body:isDestroyed() then
      asteroids[#asteroids + 1] = asteroidRecord(a)
    end
  end
  local sys = config.WorldState.system(systemId)
  sys.asteroids = asteroids
  sys.storedAt  = config.WorldState.time()
end

-- Guarda o sistema atual e remove todas as entidades, menos o jogador.
-- A carga da nave capitânia volta para a propriedade correspondente.
function WorldManager.unloadSystem()
  local player = config.Entities.getByTag("player")[1]
  WorldManager.storeSystem()
  local toRemove = {}
  for _, e in ipairs(config.Entities.all) do
    if e.tag ~= "player"  then
      toRemove[#toRemove+1] = e
    end
    if e.tag == "ship" and e.isFlagShip then
      for _, property in pairs(player.property.properties) do
        if property.ship and property.name == e.name then
          property.cargo = e.inventory.items
        end
      end
    end
  end
  for _, e in ipairs(toRemove) do
    config.Entities.remove(e)
  end
end

-- Monta um sistema a partir de data/systems.lua e do WorldState
function WorldManager.spawnSystem(systemId)
  local player = config.Entities.getByTag("player")[1]
  local sys = WorldManager.systems[systemId]
  if not sys then
    print("WARNING: System "..systemId.." not defined!")
    return
  end
  config.WorldState.setCurrentSystem(systemId)
  local sysState = config.WorldState.system(systemId)

  config.StarEntity(sys.starX,sys.starY,sys.starMass,sys.starRadius,sys.starColor)

  local starList = config.Entities.getByTag("star")
  local star = starList[1]

  config.LandableEntity(star,sys.landables,systemId)

  local asteroids = sysState.asteroids
  if asteroids then
    asteroids = advanceAsteroids(asteroids, sys, config.WorldState.time() - (sysState.storedAt or config.WorldState.time()))
  end
  config.AsteroidEntity(star,sys.asteroidCount,sys.asteroidOres,asteroids)

  config.WormholeEntity(sys.wormholes)

  config.NpcEntity(sys.population)

  for _, property in pairs(player.property.properties) do
    if property.ship and property.flagShip then
      if player.x == nil or player.y == nil then
        for _, l in ipairs(config.Entities.getByTag("landable")) do
          if l.name == player.startingScenario.starting_place then
            player.x, player.y = l.x, l.y
          end
        end
      end
      config.ShipEntity(player.x, player.y, player.name, true, property.name, property.type, nil, property.weapons, property.cargo)
    end
  end

  -- Cenário que começa pousado: player.landedAt é a tabela { name = ... } de
  -- data/starts.lua, não o landable. A nave precisa apontar para a entidade,
  -- senão o mercado é gerado numa tabela solta e a estação aparece vazia.
  if player.landedAt then
    WorldManager.placeLanded(player.landedAt.name)
    player.landedAt = false
  end

  config.Entities.sortByLayer()

  print("Loaded star system: " ..(sys.name or systemId))
end

function WorldManager.loadSystem(systemId)
  WorldManager.unloadSystem()
  WorldManager.spawnSystem(systemId)
end

-- Põe a nave capitânia pousada no landable `name` do sistema montado.
-- Devolve false se o landable não existe.
function WorldManager.placeLanded(name)
  local player = config.Entities.getByTag("player")[1]
  local ship = config.Entities.with("isFlagShip")[1]
  for _, l in ipairs(config.Entities.getByTag("landable")) do
    if l.name == name and not l.toSystem then
      player.x, player.y = l.x, l.y
      ship.rigidbody.body:setPosition(l.x, l.y)
      ship.landedAt = l
      return true
    end
  end
  return false
end

-- Descanso no landable onde a nave está pousada: o tempo avança até a manhã
-- seguinte e o sistema é montado de novo, com asteroides e NPCs renovados.
-- Os mercados não são sorteados de novo: avançam pelas horas dormidas ao
-- pousar. Devolve o tempo de jogo dormido, em segundos.
function WorldManager.rest()
  local ship = config.Entities.with("isFlagShip")[1]
  local place = ship.landedAt.name
  local systemId = config.WorldState.currentSystemId()
  local slept = config.Calendar.restDuration(config.Calendar.now())

  WorldManager.unloadSystem()
  config.WorldState.advance(config.Calendar.toSimSeconds(slept))
  config.WorldState.resetSystem(systemId)
  WorldManager.spawnSystem(systemId)
  WorldManager.placeLanded(place)
  return slept
end


return WorldManager
