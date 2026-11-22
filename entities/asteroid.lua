-- Asteroides de um sistema.
--
-- Cada asteroide é descrito por um registro de dados simples (posição,
-- velocidade, tamanho e estado da mineração). Na primeira visita os registros
-- são sorteados; nas seguintes vêm do WorldState (ver WorldManager.storeSystem).

-- Sorteia um asteroide em órbita circular em volta da estrela
local function newRecord(star)
  local theta = love.math.random() * 2 * math.pi
  local r_min_sq = config.ASTEROID_MIN_RADIUS^2
  local r_max_sq = config.ASTEROID_MAX_RADIUS^2
  local r_sq = r_min_sq + love.math.random() * (r_max_sq - r_min_sq)
  local r = math.sqrt(r_sq)

  local x = star.x + r * math.cos(theta)
  local y = star.y + r * math.sin(theta)

  local GM = config.GRAVITY_CONSTANT * star.mass
  local circular_v = math.sqrt(GM/r)

  --local speed_factor = 0.72 + love.math.random() * 0.38
  local orbital_speed = circular_v --* speed_factor

  local vx = -math.sin(theta) * orbital_speed
  local vy = math.cos(theta) * orbital_speed

  local size = love.math.random(config.MIN_ASTEROID_SIZE,config.MAX_ASTEROID_SIZE)
  local stages = math.max(1, math.round and math.round or math.floor(
    ((size - config.MIN_ASTEROID_SIZE) / (config.MAX_ASTEROID_SIZE - config.MIN_ASTEROID_SIZE)) * config.MAX_STAGES
  ))

  return {
    x = x, y = y, vx = vx, vy = vy, angle = 0, av = 0,
    size = size, radius = size,
    stage = stages, health = size, maxHealth = size,
  }
end

local function spawn(record, asteroidOres)
  local rigidBody = {}
  rigidBody.body = love.physics.newBody(config.World, record.x, record.y, "dynamic")
  rigidBody.shape = love.physics.newCircleShape(record.radius)
  rigidBody.fixture = love.physics.newFixture(rigidBody.body,rigidBody.shape)
  local color = {99/100, 87/100, 67/100}

  -- A massa vem do tamanho original: a mineração encolhe o raio, mas não a massa
  rigidBody.body:setMass(((4/3)*math.pi*(record.size)^3)*170)
  rigidBody.body:setLinearVelocity(record.vx, record.vy)
  rigidBody.body:setAngle(record.angle or 0)
  rigidBody.body:setAngularVelocity(record.av or 0)
  rigidBody.fixture:setRestitution(0.3)
  --rigidBody.body:setLinearDamping(0.12)
  rigidBody.body:setAngularDamping(0.8)

  local mineable = config.MineableComponent(record.stage, rigidBody.body:getMass(), record.size, record.maxHealth, asteroidOres)
  mineable.health = record.health

  local entity = config.Entities.create("asteroid", {
    x = record.x,
    y = record.y,
    rigidbody = config.RigidbodyComponent(rigidBody.body,rigidBody.fixture),
    sprite = config.SpriteComponent(color,rigidBody.shape,"Circle"),
    mineable = mineable,
    glow = 0,
    layer = 1
  })
  entity.rigidbody.fixture:setUserData(entity)
  return entity
end

-- records: registros guardados no WorldState; nil sorteia asteroidCount novos
return function(star, asteroidCount, asteroidOres, records)
  if not records then
    records = {}
    for i = 1, asteroidCount or 30 do
      records[i] = newRecord(star)
    end
  end
  local asteroids = {}
  for _, record in ipairs(records) do
    table.insert(asteroids, spawn(record, asteroidOres))
  end
  return asteroids
end
