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

-- Começa um jogo do zero: apaga as entidades de um jogo anterior (o menu pode
-- ser aberto em pleno voo) e cria um WorldState novo. Chamar antes de criar o
-- jogador.
function WorldManager.newGame(startingSystemId)
  config.Entities.clear()
  config.WorldState.new(startingSystemId)
end

-- Copia para o WorldState o que mudou nos landables do sistema atual (hoje,
-- o mercado). Chamar antes de descarregar o sistema e antes de salvar.
function WorldManager.storeSystem()
  local systemId = config.WorldState.currentSystemId()
  if not systemId then return end
  for _, l in ipairs(config.Entities.getByTag("landable")) do
    local record = not l.wormhole and config.WorldState.landable(systemId, l.name)
    if record and l.market and l.market.generated and l.inventory then
      record.market = {
        capacity = l.inventory.capacity,
        items    = l.inventory.items,
        prices   = l.market.prices,
      }
    end
  end
end

function WorldManager.loadSystem(systemId)
  local player = config.Entities.getByTag("player")[1]
  WorldManager.storeSystem()
  local toRemove = {}
  local currentCargo = {}
  for _, e in ipairs(config.Entities.all) do
    if e.tag ~= "player"  then
      toRemove[#toRemove+1] = e
    end
    if e.tag == "ship" and e.isFlagShip then
      currentCargo = e.inventory.items
      for _, property in pairs(player.property.properties) do
        if property.ship and property.name == e.name then
          property.cargo = currentCargo
        end
      end
    end
  end
  for _, e in ipairs(toRemove) do
    config.Entities.remove(e)
  end

  local sys = WorldManager.systems[systemId]
  if not sys then
    print("WARNING: System "..systemId.." not defined!")
    return
  end
  config.WorldState.setCurrentSystem(systemId)

  config.StarEntity(sys.starX,sys.starY,sys.starMass,sys.starRadius,sys.starColor)

  local starList = config.Entities.getByTag("star")
  local star = starList[1]

  config.LandableEntity(star,sys.landables,systemId)

  config.AsteroidEntity(star,sys.asteroidCount,sys.asteroidOres)

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
      config.ShipEntity(player.x, player.y, player.name, true, property.name, property.type, player.landedAt, property.weapons, property.cargo)
    end
  end

  config.Entities.sortByLayer()

  print("Loaded star system: " ..(sys.name or systemId))
end


return WorldManager
