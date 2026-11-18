return function(wormholes)
  for _, wormhole_data in ipairs(wormholes or {}) do
    -- Cópia: data/systems.lua é só leitura e a entidade recebe campos novos
    local data = config.DeepCopy(wormhole_data)
    data.sprite = config.SpriteComponent({0.5, 0.8, 1}, love.physics.newCircleShape(data.x, data.y, 120), "Circle")
    data.wormhole = true
    data.radius = 100
    data.layer = 0
    config.Entities.create("landable", data)
  end
end
