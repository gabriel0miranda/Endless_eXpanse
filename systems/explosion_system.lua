local ExplosionSystem = {}

function ExplosionSystem.update(ship_hash,ast_hash,dt)
  for _, explosion in ipairs(config.Entities.getByTag("explosion")) do
    if explosion.duration and explosion.duration <= 0 then
      config.Entities.remove(explosion)
    else
      for _, ship in ipairs(config.SpatialHash.query(ship_hash, config.CELL_SIZE, explosion.x, explosion.y, explosion.radius)) do
        config.DamageSystem.apply(ship,explosion.damage.shieldDamage,explosion.damage.hullDamage)
      end
      for _, ast in ipairs(config.SpatialHash.query(ast_hash, config.CELL_SIZE, explosion.x, explosion.y, explosion.radius)) do
        config.MiningSystem.damage(ast,explosion.damage.hullDamage)
      end
      explosion.duration = explosion.duration - dt
    end
  end
end

return ExplosionSystem
