return function(color,x,y,radius,duration,maxDuration,damage)
  config.Entities.create("explosion", {
    color    = color or {1, 0.2, 0, 0.4},
    x        = x,
    y        = y,
    radius   = radius or 500,
    duration = duration or 1,
    maxDuration = maxDuration or 1,
    damage   = damage or {shieldDamage = 100, hullDamage = 100},
    hit      = {},  -- alvos que já levaram dano desta explosão
  })
end
