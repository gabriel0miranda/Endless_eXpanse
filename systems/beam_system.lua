local Beam = {}

local function resolveHit(beam)
  local dirX = math.cos(beam.angle)
  local dirY = math.sin(beam.angle)
  local endX = beam.x + dirX * beam.range
  local endY = beam.y + dirY * beam.range

  local closestFraction = 1.0
  local hitEntity = nil
  local hitX, hitY = endX, endY

  config.World:rayCast(beam.x, beam.y, endX, endY,
    function(fixture, fx, fy, nx, ny, fraction)
      local e = fixture:getUserData()
      if e == nil or e == beam.owner then
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
    beam.hitX = hitX
    beam.hitY = hitY
  end

  local falloff = 1.0 - (closestFraction*0.8)
  if hitEntity then
    if hitEntity.mineable then
      config.MiningSystem.damage(hitEntity, beam.damage.hullDamage*falloff)
    else
      config.DamageSystem.apply(hitEntity, beam.damage.shieldDamage*falloff, beam.damage.hullDamage*falloff, beam.owner)
    end
  end
end

function Beam.update(dt)
  for _, beam in ipairs(config.Entities.getByTag("beam")) do
    beam.hitX = nil
    beam.hitY = nil
    if not beam.owner.weapons[beam.owner.currentWeapon].firing or not beam.owner or not beam.owner.rigidbody or not beam.owner.rigidbody.body or beam.owner.rigidbody.body:isDestroyed() then
      if beam.owner.weapons[beam.owner.currentWeapon].def.type == "beam" then
        beam.owner.weapons[beam.owner.currentWeapon].capacitor.current = 0
        beam.owner.weapons[beam.owner.currentWeapon].beam = nil
      end
      config.Entities.remove(beam)
    else
      beam.x, beam.y = beam.owner.rigidbody.body:getWorldCenter()
      beam.angle = beam.owner.rigidbody.body:getAngle()
      resolveHit(beam)
    end
  end
end

return Beam
