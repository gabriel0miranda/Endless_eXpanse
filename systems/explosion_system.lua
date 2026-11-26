local ExplosionSystem = {}

-- Fração do dano que ainda chega na borda do raio (no centro é 100%)
local EDGE_DAMAGE = 0.25

-- Atenuação linear pela distância ao centro; nil se o alvo está fora do raio
local function falloff(explosion, x, y)
  local dx, dy = x - explosion.x, y - explosion.y
  local dist = math.sqrt(dx*dx + dy*dy)
  if dist > explosion.radius then return nil end
  return 1 - (1 - EDGE_DAMAGE) * (dist / explosion.radius)
end

local function alive(entity)
  return not entity.removed and entity.rigidbody and entity.rigidbody.body
     and not entity.rigidbody.body:isDestroyed()
end

function ExplosionSystem.update(ship_hash,ast_hash,dt)
  for _, explosion in ipairs(config.Entities.getByTag("explosion")) do
    if explosion.duration and explosion.duration <= 0 then
      config.Entities.remove(explosion)
    else
      -- A explosão dura vários frames (para a animação), mas cada alvo só leva dano uma vez
      for _, ship in ipairs(config.SpatialHash.query(ship_hash, config.CELL_SIZE, explosion.x, explosion.y, explosion.radius)) do
        if not explosion.hit[ship] and alive(ship) then
          local f = falloff(explosion, ship.rigidbody.body:getPosition())
          if f then
            explosion.hit[ship] = true
            config.DamageSystem.apply(ship, explosion.damage.shieldDamage * f, explosion.damage.hullDamage * f, explosion.source)
          end
        end
      end
      for _, ast in ipairs(config.SpatialHash.query(ast_hash, config.CELL_SIZE, explosion.x, explosion.y, explosion.radius)) do
        if not explosion.hit[ast] and alive(ast) then
          local f = falloff(explosion, ast.rigidbody.body:getPosition())
          if f then
            explosion.hit[ast] = true
            config.MiningSystem.damage(ast, explosion.damage.hullDamage * f)
          end
        end
      end
      explosion.duration = explosion.duration - dt
    end
  end
end

return ExplosionSystem
