local Helper = require("spec.helper")

describe("Market", function()
  local Market

  before_each(function()
    Helper.setup()
    Market = config.MarketSystem
  end)

  local function newStation(demanded)
    return {
      market = { capacity = 20000, demanded = demanded or {}, stock = {} },
    }
  end

  it("cobra sempre mais do que paga pelo mesmo item", function()
    for _ = 1, 50 do
      local station = newStation({ ["Silver Ore"] = 2.0, ["Cocaine"] = 3.0 })
      Market.generateStock(station)
      for item, price in pairs(station.market.prices) do
        assert.is_true(price.sell > price.buy, item .. ": sell " .. price.sell .. " <= buy " .. price.buy)
      end
    end
  end)

  it("dá prejuízo ao comprar e revender na mesma estação", function()
    local station = newStation()
    station.market.stock = { { item = "Water", min = 100, max = 100 } }
    Market.generateStock(station)

    config.Entities.clear()
    local player = config.Entities.create("player", { credits = config.CreditsComponent(10000) })
    local ship = { inventory = config.InventoryComponent(1000) }

    assert.is_true(Market.executeTrade(station, ship, {}, { { item = "Water", qty = 10 } }))
    assert.is_true(Market.executeTrade(station, ship, { { item = "Water", qty = 10 } }, {}))
    assert.is_true(player.credits.amount < 10000)
  end)

  it("cria o mercado de um negociante sem inventário", function()
    local trader = {}
    assert.has_no.errors(function() Market.generateStock(trader) end)
    assert.is_not_nil(trader.inventory)
    assert.is_not_nil(trader.market.prices["Iron Ore"])
  end)
end)
