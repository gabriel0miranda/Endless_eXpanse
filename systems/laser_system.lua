local LaserSystem = {}

local function resolveHit(laser)
  if laser.hitX then return end
  local dirX = math.cos(laser.angle)
  local dirY = math.sin(laser.angle)
  local endX = laser.x + dirX * laser.range
  local endY = laser.y + dirY * laser.range

  local closestFraction = 1.0
  local hitEntity = nil
  local hitX, hitY = endX, endY

  config.World:rayCast(laser.x, laser.y, endX, endY,
    function(fixture, fx, fy, nx, ny, fraction)
      local e = fixture:getUserData()
      if e == nil or e == laser.owner then
        return 1  -- ignora, continua
      end
      if fraction < closestFraction then
        closestFraction = fraction
        hitEntity = e
        hitX, hitY = fx, fy
      end
      return fraction  -- só aceita hits mais próximos daqui pra frente
    end
  )

  if hitEntity then
    laser.hitX = hitX
    laser.hitY = hitY
  end

  local falloff = 1.0 - (closestFraction*0.8)
  if hitEntity then
    if hitEntity.mineable then
      config.MiningSystem.damage(hitEntity, laser.damage.hullDamage*falloff)
    else
      config.DamageSystem.apply(hitEntity, laser.damage.shieldDamage*falloff, laser.damage.hullDamage*falloff, laser.owner)
    end
  end
end

function LaserSystem.update(dt)
  for _, laser in ipairs(config.Entities.getByTag("laser")) do
    local dirX = math.cos(laser.angle)
    local dirY = math.sin(laser.angle)
    local endX = laser.firedFromX + dirX * laser.range
    local endY = laser.firedFromY + dirY * laser.range
    local tipX = laser.x + dirX * laser.lenght
    local tipY = laser.y + dirY * laser.lenght
    local dx, dy = endX - tipX, endY - tipY
    local dist   = math.sqrt(dx*dx + dy*dy)
    if dist <= laser.lenght or laser.hitX or not laser.owner or not laser.owner.rigidbody or not laser.owner.rigidbody.body or laser.owner.rigidbody.body:isDestroyed() then
      config.Entities.remove(laser)
    else
      resolveHit(laser)
      laser.x = laser.x + (endX - laser.firedFromX)*dt
      laser.y = laser.y + (endY - laser.firedFromY)*dt
    end
  end
end

return LaserSystem
