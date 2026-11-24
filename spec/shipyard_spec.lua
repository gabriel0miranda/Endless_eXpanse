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

  it("o vendedor só avisa da carga quando há carga e a moeda cai do lado do aviso", function()
    local Shipyard = config.ShipyardSystem
    assert.is_true(Shipyard.buyShip(player, "PP-2340", "Nova"))
    local vazia = player.property.properties["Nova"]
    local cheia = { ship = true, cargo = { Water = 3 } }
    local zerada = { ship = true, cargo = { Water = 0 } }
    assert.is_false(Shipyard.sellerWarnsCargo(vazia, 0.1))
    assert.is_false(Shipyard.sellerWarnsCargo(zerada, 0.1))
    assert.is_true(Shipyard.sellerWarnsCargo(cheia, 0.1))
    assert.is_false(Shipyard.sellerWarnsCargo(cheia, 0.9))
  end)
end)
