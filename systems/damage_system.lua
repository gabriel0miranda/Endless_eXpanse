local DamageSystem = {}

-- Nave com hull <= 0 fica desativada (sem motor nem armas). Depois de STASIS_TIME
-- segundos sem levar dano, o hull recarrega RECOVERY_RATE do máximo por segundo
-- até RECOVERED_HULL, e a nave volta a funcionar. Hull <= -máximo destrói a nave.
local STASIS_TIME     = 10
local RECOVERY_RATE   = 0.05
local RECOVERED_HULL  = 0.10
-- Fração do hull da nave destruída que vira dano da explosão
local EXPLOSION_POWER = 0.5

function DamageSystem.apply(entity, shieldDamage, hullDamage)
  if not entity.disabled and entity.shields and entity.shields.currentCapacity > 0 then
    entity.shields.currentCapacity = math.max(entity.shields.currentCapacity-shieldDamage, 0)
    entity.shields.currentCooldown = entity.shields.cooldown
    return
  end
  if entity.hull then
    entity.hull.currentHealth = entity.hull.currentHealth-hullDamage
  end
  -- Dano durante a estase reinicia a contagem
  if entity.disabled then
    entity.stasisTimer = STASIS_TIME
  end
end

local function explode(ship)
  local power = ship.hull.health * EXPLOSION_POWER
  config.ExplosionEntity(nil,
    ship.rigidbody.body:getX(),
    ship.rigidbody.body:getY(),
    ship.rigidbody.fixture:getShape():getRadius()+200,
    1,1,
    {shieldDamage=power,
     hullDamage=power}
   )
end

local function disable(ship)
  ship.disabled = true
  ship.stasisTimer = STASIS_TIME
end

local function recover(ship, dt)
  if ship.stasisTimer > 0 then
    ship.stasisTimer = ship.stasisTimer - dt
    return
  end
  local hull = ship.hull
  local target = hull.health * RECOVERED_HULL
  hull.currentHealth = hull.currentHealth + hull.health * RECOVERY_RATE * dt
  if hull.currentHealth >= target then
    hull.currentHealth = target
    ship.disabled = false
    ship.stasisTimer = nil
  end
end

function DamageSystem.update(dt)
  local destroyed = {}
  for _, ship in ipairs(config.Entities.getByTag("ship")) do
    if ship.hull.currentHealth <= -ship.hull.health then
      explode(ship)
      destroyed[#destroyed+1] = ship
    elseif ship.disabled then
      recover(ship, dt)
    elseif ship.hull.currentHealth <= 0 then
      disable(ship)
    end
  end
  -- Remove depois do laço: getByTag devolve a mesma lista que Entities.remove altera
  for _, ship in ipairs(destroyed) do
    config.Entities.remove(ship)
  end
end

return DamageSystem
