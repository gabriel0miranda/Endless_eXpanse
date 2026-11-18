local Helper = require("spec.helper")

describe("PlayerEntity", function()
  before_each(function()
    Helper.setup()
    config.Entities.clear()
  end)

  it("indexa as propriedades iniciais pelo nome", function()
    local start = config.Starts["Young Noobinobi"]
    local player = config.PlayerEntity(start, "Teste")
    local ship = start.starting_property[1]

    assert.is_true(player.property:has(ship))
    assert.is_true(player.property:remove(ship))
    assert.is_false(player.property:has(ship))
  end)

  it("não altera os dados do cenário inicial", function()
    local start = config.Starts["Young Noobinobi"]
    local originalCocaine = start.starting_property[1].cargo["Cocaine"]

    local player = config.PlayerEntity(start, "Teste")
    local ship = player.property.properties[start.starting_property[1].name]
    ship.cargo["Cocaine"] = 0
    ship.flagShip = false

    assert.are.equal(originalCocaine, start.starting_property[1].cargo["Cocaine"])
    assert.is_true(start.starting_property[1].flagShip)
  end)

  it("deixa a posição para o WorldManager quando o cenário não define x/y", function()
    local player = config.PlayerEntity(config.Starts["Iron Baller"], "")
    assert.is_nil(player.x)
    assert.are.equal("Boleiro de Ferro", player.name)
  end)
end)
