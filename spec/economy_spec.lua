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

  it("roda cada receita de uma indústria de forma independente", function()
    config.Industries["Smelter"] = { recipes = {
      { inputs = { ["Silver Ore"] = 2 }, outputs = { ["Silver Ingot"] = 1 } },
      { inputs = { ["Gold Ore"] = 2 },   outputs = { ["Gold Ingot"] = 1 } },
    } }
    -- Sem ouro, a prata continua saindo
    assert.are.same({ ["Silver Ingot"] = 3 }, produce({ industries = { ["Smelter"] = 1 } }, { ["Silver Ore"] = 6 }, 3))
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

describe("Sortimento sorteado", function()
  local DAY = 24 * 3600
  local spec = { count = 4, min = 100, max = 100, days = 7, exclude = { trash = true } }

  before_each(function()
    Helper.setup()
    config.CalendarData = require("data.calendar")
    config.WorldState = require("managers.world_state")
    config.Calendar = require("managers.calendar")
    config.WorldState.new(1, 0)
  end)

  local function station()
    local data = { capacity = 100000, stock = {}, assortment = spec }
    return { market = { generated = false, data = data, capacity = data.capacity, demanded = {}, prices = {} } }
  end

  local function names(assortment)
    local set = {}
    for _, entry in ipairs(assortment) do set[entry.item] = true end
    return set
  end

  it("sorteia itens distintos fora das categorias excluídas", function()
    for _ = 1, 30 do
      local list = config.Economy.rollAssortment(spec)
      local set = names(list)
      local n = 0
      for item in pairs(set) do
        n = n + 1
        assert.are_not.equal("trash", config.Items[item].category)
      end
      assert.are.equal(4, n)
    end
  end)

  it("vende os itens sorteados perto do preço base", function()
    local s = station()
    config.MarketSystem.openLandable(s)
    for _, entry in ipairs(s.market.assortment) do
      assert.is_true((s.inventory.items[entry.item] or 0) > 0, entry.item)
      local base = config.Items[entry.item].basePrice
      local mid = (s.market.prices[entry.item].buy + s.market.prices[entry.item].sell) / 2
      assert.is_true(mid > base * 0.7 and mid < base * 1.3, entry.item .. ": " .. mid .. " vs " .. base)
    end
  end)

  it("troca o sortimento depois do prazo, com estoque nos itens novos", function()
    local s = station()
    config.MarketSystem.openLandable(s)
    local first = s.market.assortment

    config.WorldState.advance(config.Calendar.toSimSeconds(3 * DAY))
    config.MarketSystem.openLandable(s)
    assert.are.equal(first, s.market.assortment)  -- ainda no prazo

    config.WorldState.advance(config.Calendar.toSimSeconds(5 * DAY))
    config.MarketSystem.openLandable(s)
    assert.are_not.equal(first, s.market.assortment)
    for _, entry in ipairs(s.market.assortment) do
      assert.is_true((s.inventory.items[entry.item] or 0) > 0, entry.item)
    end
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

-- Cada item precisa de uma fonte (indústria ou asteroide) e de um consumidor
-- (insumo de alguma indústria). Sem isso, o item some dos mercados quando o
-- comércio de fundo der lugar ao tick global, ou não tem rota que dê lucro.
-- O sortimento da Estação de Troca não conta: ele só revende.
describe("Cadeias de suprimento", function()
  -- Exceções conhecidas, com o motivo; apagar quando forem resolvidas
  local KNOWN = {
    noSource = {},
    noConsumer = {
      ["Gold Ingot"] = "fica para a PR de expansão do comércio",
    },
  }

  local sources, consumers

  before_each(function()
    Helper.setup()
    sources, consumers = {}, {}
    for name, landable in pairs(require("data.landables")) do
      if landable.market then
        local consumed, produced = config.Economy.uses(landable.market)
        for item in pairs(produced) do sources[item] = name end
        for item in pairs(consumed) do consumers[item] = name end
      end
    end
    for _, sys in pairs(require("data.systems")) do
      for _, ore in ipairs(sys.asteroidOres or {}) do sources[ore.item] = sources[ore.item] or sys.name end
    end
  end)

  local function check(map, known, message)
    local missing = {}
    for item, data in pairs(config.Items) do
      if data.category ~= "trash" and not map[item] and not known[item] then
        missing[#missing + 1] = item
      end
    end
    table.sort(missing)
    assert.are.same({}, missing, message)
  end

  it("todo item tem uma fonte", function()
    check(sources, KNOWN.noSource, "itens sem indústria que os produza nem asteroide que os contenha")
  end)

  it("todo item tem um consumidor", function()
    check(consumers, KNOWN.noConsumer, "itens que nenhuma indústria consome")
  end)

  it("as exceções conhecidas ainda são exceções", function()
    for item, reason in pairs(KNOWN.noConsumer) do
      assert.is_nil(consumers[item], item .. " já tem consumidor: remova de KNOWN (" .. reason .. ")")
    end
    for item, reason in pairs(KNOWN.noSource) do
      assert.is_nil(sources[item], item .. " já tem fonte: remova de KNOWN (" .. reason .. ")")
    end
  end)
end)
