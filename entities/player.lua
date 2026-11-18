return function(start, playerName)
  playerName = playerName ~= "" and playerName or start.name
  -- Indexadas pelo nome, como em PropertyComponent.add; copiadas para não alterar data/starts.lua
  local property_owned = {}
  for _, property in ipairs(start.starting_property) do
    property_owned[property.name] = config.DeepCopy(property)
  end

  return config.Entities.create("player", {
    name      = playerName,
    property  = config.PropertyComponent(property_owned),
    credits          = config.CreditsComponent(start.starting_credits),
    -- Sem x/y no cenário, WorldManager.loadSystem posiciona no starting_place
    x         = start.x,
    y         = start.y,
    landedAt  = start.landedAt,
    startingScenario = start
  })
end
