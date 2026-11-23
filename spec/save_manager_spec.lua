local Helper = require("spec.helper")

describe("SaveManager.renameItems", function()
  before_each(function()
    Helper.setup()
    config.SaveManager = require("managers.save_manager")
  end)

  it("troca a grafia antiga de um item em chaves e valores", function()
    local data = {
      world = { systems = { ["4"] = { landables = { Flutura = { market = {
        items = { ["Phosporus"] = 120, ["Water"] = 5 },
        noise = { ["Phosporus"] = 1.1 },
        assortment = { { item = "Phosporus", min = 150, max = 200 } },
      } } } } } },
      player = { properties = { Nave = { cargo = { ["Phosporus"] = 3 } } } },
    }
    config.SaveManager.renameItems(data)

    local market = data.world.systems["4"].landables.Flutura.market
    assert.are.same({ ["Phosphorus"] = 120, ["Water"] = 5 }, market.items)
    assert.are.same({ ["Phosphorus"] = 1.1 }, market.noise)
    assert.are.equal("Phosphorus", market.assortment[1].item)
    assert.are.same({ ["Phosphorus"] = 3 }, data.player.properties.Nave.cargo)
  end)

  it("só renomeia itens que existem nos dados", function()
    for _, new in pairs(config.SaveManager.ITEM_RENAMES) do
      assert.is_not_nil(config.Items[new], new)
    end
  end)
end)

describe("SaveManager.dropUnknownItems", function()
  before_each(function()
    Helper.setup()
    config.SaveManager = require("managers.save_manager")
  end)

  it("descarta itens que não existem mais e mantém os outros", function()
    local data = {
      world = { systems = { ["1"] = { landables = { Estacao = { market = {
        items = { ["Unobtainium"] = 50, ["Water"] = 5 },
        noise = { ["Unobtainium"] = 1.1, ["Water"] = 0.9 },
        assortment = { { item = "Unobtainium", min = 1, max = 2 }, { item = "Water", min = 1, max = 2 } },
      } } } } } },
      player = { properties = { Nave = { ship = true, cargo = { ["Unobtainium"] = 3, ["Water"] = 1 } } } },
    }
    local dropped = config.SaveManager.dropUnknownItems(data)

    local market = data.world.systems["1"].landables.Estacao.market
    assert.are.same({ ["Water"] = 5 }, market.items)
    assert.are.same({ ["Water"] = 0.9 }, market.noise)
    assert.are.same({ { item = "Water", min = 1, max = 2 } }, market.assortment)
    assert.are.same({ ["Water"] = 1 }, data.player.properties.Nave.cargo)
    assert.are.equal(4, #dropped)
  end)

  it("não mexe num save só com itens válidos", function()
    local data = { world = { systems = {} }, player = { properties = { Nave = { cargo = { ["Water"] = 1 } } } } }
    assert.are.same({}, config.SaveManager.dropUnknownItems(data))
    assert.are.same({ ["Water"] = 1 }, data.player.properties.Nave.cargo)
  end)
end)
