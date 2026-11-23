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
