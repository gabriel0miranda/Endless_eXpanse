local Helper = require("spec.helper")

describe("Shipyard", function()
  local player

  before_each(function()
    Helper.setup()
    config.Ships = require("data.ships")
    config.ShipyardSystem = require("systems.shipyard")
    config.Entities.clear()
    player = config.PlayerEntity(config.Starts["Lost Peregrine"], "Teste")
    player.credits.amount = 1000000
  end)

  local function flagShips()
    local names = {}
    for name, p in pairs(player.property.properties) do
      if p.ship and p.flagShip then names[#names + 1] = name end
    end
    return names
  end

  it("passa o posto de nave ativa ao vender a nave ativa", function()
    local Shipyard = config.ShipyardSystem
    assert.is_true(Shipyard.buyShip(player, "PP-2340", "Nova"))
    local ok = Shipyard.sellShip(player, player.property.properties["Corélia"])
    assert.is_true(ok)
    assert.are.same({ "Nova" }, flagShips())
  end)

  it("não vende a única nave da frota", function()
    local ok = config.ShipyardSystem.sellShip(player, player.property.properties["Corélia"])
    assert.is_false(ok)
    assert.are.same({ "Corélia" }, flagShips())
  end)
end)
