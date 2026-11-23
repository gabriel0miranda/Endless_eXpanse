-- Ângulo da órbita no instante `time`: a posição é função do relógio do mundo,
-- então o planeta continua girando mesmo com o jogador em outro sistema.
local function orbitAngleAt(phase, orbitSpeed, time)
  return phase + orbitSpeed * time
end

-- Primeira visita: sorteia a fase orbital (ou a deduz de x/y fixos nos dados)
local function newRecord(star, landable_data)
  local phase
  if landable_data.orbitRadius then
    phase = love.math.random() * 2 * math.pi
  else
    phase = math.atan2((landable_data.y or 0) - star.y, (landable_data.x or 0) - star.x)
  end
  return { phase = phase }
end

-- Mercado da entidade: dados fixos vêm de config.Landables; estoque,
-- flutuação e hora da última atualização, se a estação já foi visitada, vêm
-- do registro no WorldState. Os preços são calculados ao pousar
-- (MarketSystem.openLandable).
local function buildMarket(landable_data, record)
  local market = {
    generated = false,
    prices = {},
    data = landable_data.market,
    capacity = landable_data.market and landable_data.market.capacity or 0,
    stock = landable_data.market and landable_data.market.stock or {},
    -- Itens que as indústrias do local consomem: destacados no MarketUI
    demanded = landable_data.market and (config.Economy.uses(landable_data.market)) or {}
  }
  local inventory = nil
  if record.market and landable_data.market then
    market.generated = true
    market.noise = record.market.noise or {}
    market.updatedAt = record.market.updatedAt  -- nil em saves anteriores à economia
    market.assortment = record.market.assortment
    market.assortmentAt = record.market.assortmentAt
    inventory = config.InventoryComponent(market.capacity, record.market.items)
  end
  return market, inventory
end

return function(star, landables, systemId)
  for _, landable in ipairs(landables or {}) do
    -- config.Landables é só leitura: o que muda em jogo fica no WorldState
    local landable_data = config.Landables[landable]
    local record = config.WorldState.landable(systemId, landable)
    if not record then
      record = newRecord(star, landable_data)
      config.WorldState.setLandable(systemId, landable, record)
    end

    local orbitRadius = landable_data.orbitRadius
      or math.sqrt(((landable_data.x or 0) - star.x)^2 + ((landable_data.y or 0) - star.y)^2)
    local orbitSpeed = landable_data.orbitSpeed or 0.0005
    local orbitAngle = orbitAngleAt(record.phase, orbitSpeed, config.WorldState.time())
    local x = star.x + orbitRadius * math.cos(orbitAngle)
    local y = star.y + orbitRadius * math.sin(orbitAngle)

    local sprite = config.SpriteComponent(landable_data.color,love.physics.newCircleShape(x,y,landable_data.radius),"Circle")
    local market, inventory = buildMarket(landable_data, record)

    local shipyard = {
        generated = false,
        prices = {},
        stock = landable_data.shipyard and landable_data.shipyard.stock or {},
    }
    config.Entities.create("landable",{
      name=landable,
      x=x,
      y=y,
      radius=landable_data.radius,
      sprite=sprite,
      market=market,
      inventory=inventory,
      shipyard=shipyard,
      orbitRadius=orbitRadius,
      orbitPhase=record.phase,
      orbitAngle=orbitAngle,
      orbitSpeed=orbitSpeed,
      layer = 0
    })
  end
end
