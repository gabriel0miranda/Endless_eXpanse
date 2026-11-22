local Helper = require("spec.helper")

describe("Economy", function()
  local Economy

  before_each(function()
    Helper.setup()
    Economy = config.Economy
    config.Industries = {
      ["Mill"] = { inputs = { ["Iron Ore"] = 10 }, outputs = { ["Steel Sheets"] = 5 } },
      ["Well"] = { outputs = { ["Water"] = 10 } },
    }
  end)

  -- Avança sem comércio de fundo nem flutuação, para medir só as indústrias
  local function produce(marketData, items, hours, capacity)
    local relax = Economy.RELAX_PER_HOUR
    Economy.RELAX_PER_HOUR = 0
    local state = { items = items, capacity = capacity or 100000 }
    Economy.advance(marketData, state, hours)
    Economy.RELAX_PER_HOUR = relax
    return state.items
  end

  it("soma o alvo das indústrias e do estoque inicial", function()
    local targets = Economy.targets({
      industries = { ["Mill"] = 2 },
      stock = { { item = "Water", min = 100, max = 300 } },
    })
    assert.are.equal(20 * Economy.TARGET_HOURS, targets["Iron Ore"])
    assert.are.equal(10 * Economy.TARGET_HOURS, targets["Steel Sheets"])
    assert.are.equal(200, targets["Water"])
  end)

  it("produz na fração que o insumo permite", function()
    local data = { industries = { ["Mill"] = 1 } }
    assert.are.same({ ["Steel Sheets"] = 10 }, produce(data, { ["Iron Ore"] = 20 }, 2))
    assert.are.same({ ["Steel Sheets"] = 3 }, produce(data, { ["Iron Ore"] = 5 }, 1))   -- metade: 2,5 → 3
    assert.are.same({}, produce(data, {}, 5))
  end)

  it("para de produzir quando o armazém enche", function()
    local items = produce({ industries = { ["Well"] = 1 } }, {}, 10, 25)  -- Water tem volume 1
    assert.are.equal(25, items["Water"])
  end)

  it("puxa o estoque para o alvo com o comércio de fundo", function()
    local data = { stock = { { item = "Water", min = 1000, max = 1000 } } }
    local state = { items = { ["Water"] = 0, ["Iron Ore"] = 500 }, capacity = 100000 }
    Economy.advance(data, state, 100)
    assert.is_true(state.items["Water"] > 800)
    assert.is_true((state.items["Iron Ore"] or 0) < 100)  -- alvo 0: o excesso é exportado
  end)

  it("encarece o item escasso e barateia o abundante", function()
    local data = { stock = { { item = "Water", min = 1000, max = 1000 } } }
    local scarce   = Economy.prices(data, { ["Water"] = 100 })["Water"]
    local abundant = Economy.prices(data, { ["Water"] = 5000 })["Water"]
    assert.is_true(scarce.sell > abundant.sell)
    assert.is_true(scarce.sell > scarce.buy and abundant.sell > abundant.buy)
  end)

  it("separa os itens consumidos dos produzidos", function()
    local consumed, produced = Economy.uses({ industries = { ["Mill"] = 1 } })
    assert.are.same({ ["Iron Ore"] = true }, consumed)
    assert.are.same({ ["Steel Sheets"] = true }, produced)
  end)

  it("recusa receita com item inexistente", function()
    config.Industries["Bad"] = { inputs = { ["Unobtainium"] = 1 } }
    assert.has_error(function() Economy.targets({ industries = { ["Bad"] = 1 } }) end,
      "Item não definido em data/items.lua: Unobtainium (indústria Bad)")
  end)

  it("guarda a fração de hora que ainda não foi simulada", function()
    local hours, updatedAt = Economy.elapsedHours(0, 3 * 3600 + 1200)
    assert.are.equal(3, hours)
    assert.are.equal(3 * 3600, updatedAt)
  end)
end)

describe("MarketSystem.openLandable", function()
  local landData = { capacity = 100000, industries = { ["Well"] = 1 }, demanded = {}, stock = {} }

  before_each(function()
    Helper.setup()
    config.Industries = { ["Well"] = { outputs = { ["Water"] = 10 } } }
    config.CalendarData = require("data.calendar")
    config.WorldState = require("managers.world_state")
    config.Calendar = require("managers.calendar")
    config.WorldState.new(1, 0)
  end)

  local function station()
    return { market = { generated = false, data = landData, capacity = landData.capacity, demanded = {}, prices = {} } }
  end

  it("gera estoque e preços na primeira visita", function()
    local s = station()
    config.MarketSystem.openLandable(s)
    assert.is_true(s.market.generated)
    assert.is_true(s.inventory.items["Water"] > 0)
    assert.is_not_nil(s.market.prices["Water"])
  end)

  it("avança o mercado pelas horas passadas desde a última visita", function()
    local s = station()
    config.MarketSystem.openLandable(s)
    s.inventory:remove("Water", s.inventory.items["Water"])   -- o jogador compra tudo
    config.MarketSystem.refreshPrices(s)
    local emptyPrice = s.market.prices["Water"].sell

    config.WorldState.advance(config.Calendar.toSimSeconds(10 * 3600))  -- 10 h de voo
    config.MarketSystem.openLandable(s)
    assert.is_true(s.inventory.items["Water"] >= 100)  -- 10 h de poço
    assert.is_true(s.market.prices["Water"].sell < emptyPrice)
  end)
end)

describe("Dados da economia", function()
  before_each(function() Helper.setup() end)

  it("só usam indústrias e itens que existem", function()
    for name, landable in pairs(require("data.landables")) do
      local market = landable.market
      if market then
        local ok, err = pcall(config.Economy.targets, market)
        assert.is_true(ok, name .. ": " .. tostring(err))
        for _, entry in ipairs(market.stock or {}) do
          assert.is_not_nil(config.Items[entry.item], name .. ": item de stock inexistente " .. entry.item)
        end
      end
    end
  end)

  it("só usam itens que existem em todas as receitas", function()
    for key in pairs(config.Industries) do
      local ok, err = pcall(config.Economy.uses, { industries = { [key] = 1 } })
      assert.is_true(ok, tostring(err))
    end
  end)
end)
