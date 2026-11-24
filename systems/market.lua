local Market = {}

-- Margem entre o que a estação paga e o que ela cobra (0.1 = ±10% do preço médio)
local SPREAD = 0.1

-- Preço base global por item (fallback)
local function getBasePrices()
  local basePrices = {}
  for item, data in pairs(config.Items) do
    basePrices[item] = data.basePrice
  end
  return basePrices
end

-- Mercado de um landable ao pousar: na primeira visita sorteia o estoque;
-- nas seguintes avança a economia pelas horas passadas desde a última
-- (systems/economy.lua). Em seguida recalcula os preços.
function Market.openLandable(trader)
  local market = trader.market
  local now = config.Calendar.now()
  if not market.generated then
    if market.data.assortment then
      market.assortment = config.Economy.rollAssortment(market.data.assortment)
      market.assortmentAt = now
    end
    trader.inventory = config.InventoryComponent(market.capacity, config.Economy.newStock(Market.economyData(trader)))
    market.noise = {}
    market.updatedAt = now
    market.generated = true
    Market.advanceLandable(trader, config.Economy.WARMUP_HOURS)
  else
    local hours, updatedAt = config.Economy.elapsedHours(market.updatedAt or now, now)
    market.updatedAt = updatedAt
    Market.advanceLandable(trader, hours)
    Market.rotateAssortment(trader, now)
  end
  Market.refreshPrices(trader)
end

-- Dados que a economia usa para este mercado: os fixos de data/landables.lua
-- mais o sortimento sorteado, se houver
function Market.economyData(trader)
  return config.Economy.withAssortment(trader.market.data, trader.market.assortment)
end

-- Troca o sortimento quando ele vence. Os itens novos chegam com estoque
-- cheio; os que saíram ficam com alvo 0 e o comércio de fundo os escoa.
function Market.rotateAssortment(trader, now)
  local market = trader.market
  local spec = market.data.assortment
  if not spec then return end
  local DAY = config.CalendarData.hoursPerDay * 3600
  if market.assortment and now - (market.assortmentAt or now) < spec.days * DAY then return end
  local old = {}
  for _, entry in ipairs(market.assortment or {}) do old[entry.item] = true end
  market.assortment = config.Economy.rollAssortment(spec)
  market.assortmentAt = now
  for _, entry in ipairs(market.assortment) do
    if not old[entry.item] then
      trader.inventory:add(entry.item, entry.min + math.floor(love.math.random() * (entry.max - entry.min)))
    end
  end
end

function Market.advanceLandable(trader, hours)
  if hours <= 0 then return end
  local state = { items = trader.inventory.items, noise = trader.market.noise, capacity = trader.market.capacity }
  config.Economy.advance(Market.economyData(trader), state, hours)
  trader.market.noise = state.noise
  -- Recria o inventário para recalcular o volume ocupado
  trader.inventory = config.InventoryComponent(trader.market.capacity, state.items)
end

-- Só landables têm preço derivado do estoque; NPCs usam generateStock
function Market.refreshPrices(trader)
  if not trader.market.data then return end
  trader.market.prices = config.Economy.prices(Market.economyData(trader), trader.inventory.items, trader.market.noise)
end

-- Estoque e preços fixos de quem não tem economia própria (naves NPC)
function Market.generateStock(trader)
  local market = {}
  if not trader.market then
    trader.market = {}
    trader.market.capacity = trader.inventory and trader.inventory.capacity or 100
    trader.market.stock = {}
    for item, qty in pairs(trader.inventory and trader.inventory.items or {}) do
      table.insert(trader.market.stock,{item=item,min=qty,max=qty})
    end
  end
  market = trader.market
  if market.generated then return end

  -- Inicializa o inventário se não existir
  if not trader.inventory then
    trader.inventory = config.InventoryComponent(market.capacity or 10000)
  end

  for _, entry in ipairs(market.stock or {}) do
    local qty = entry.min + math.floor(love.math.random() * (entry.max - entry.min))
    trader.inventory:add(entry.item, qty)
  end

  -- Gera tabela de preços de compra e venda
  -- Compra e venda ficam sempre em lados opostos do preço médio, então comprar
  -- e revender no mesmo lugar dá prejuízo.
  local prices = {}
  for item, basePrice in pairs(getBasePrices()) do
    local midPrice  = basePrice * (0.9 + love.math.random() * 0.2)
    local buyPrice  = math.floor(midPrice * (1 - SPREAD))
    local sellPrice = math.ceil(midPrice * (1 + SPREAD))
    prices[item] = {
      buy  = buyPrice,   -- preço que a estação paga ao jogador
      sell = sellPrice,  -- preço que a estação cobra do jogador
    }
  end

  trader.market.prices = prices
  trader.market.generated = true
  if config.Input.state.debugFlag then
    config.DumpTable(market)
  end
end

-- Calcula o balanço de uma troca
-- offering: { {item, qty}, ... } — o que o jogador oferece
-- requesting: { {item, qty}, ... } — o que o jogador quer
-- Retorna: balanço em créditos (positivo = jogador recebe, negativo = jogador paga)
function Market.calculateBalance(trader, offering, requesting)
    local balance = 0
    for _, o in ipairs(offering) do
        local price = trader.market.prices and trader.market.prices[o.item]
        balance = balance + (price and price.buy or 0) * o.qty
    end
    for _, r in ipairs(requesting) do
        local price = trader.market.prices and trader.market.prices[r.item]
        balance = balance - (price and price.sell or 0) * r.qty
    end
    return balance
end

-- Executa a troca se válida
function Market.executeTrade(trader, ship, offering, requesting)
    local balance = Market.calculateBalance(trader, offering, requesting)
    local player = config.Entities.getByTag("player")[1]

    -- Verifica se jogador tem créditos suficientes
    if balance < 0 and player.credits.amount < -balance then
        return false, "Créditos insuficientes"
    end

    -- Verifica se estação tem os itens pedidos
    for _, r in ipairs(requesting) do
        if not trader.inventory:has(r.item, r.qty) then
            return false, "Estação não tem " .. r.item
        end
    end

    -- Verifica se jogador tem os itens oferecidos
    for _, o in ipairs(offering) do
        if not ship.inventory:has(o.item, o.qty) then
            return false, "Você não tem " .. o.item
        end
    end

    -- Verifica espaço dos dois lados: InventoryComponent:add corta a quantidade
    -- quando falta espaço, e o item pago sumiria no meio da troca
    local function volume(list)
        local total = 0
        for _, entry in ipairs(list) do
            total = total + (config.Items[entry.item].volume or 1) * entry.qty
        end
        return total
    end
    local offered, requested = volume(offering), volume(requesting)
    if ship.inventory.capacityUsed - offered + requested > ship.inventory.capacity then
        return false, "Sem espaço no porão"
    end
    if trader.inventory.capacityUsed - requested + offered > trader.inventory.capacity then
        return false, "A estação não tem espaço"
    end

    -- Executa
    for _, o in ipairs(offering) do
        ship.inventory:remove(o.item, o.qty)
        trader.inventory:add(o.item, o.qty)
    end
    for _, r in ipairs(requesting) do
        trader.inventory:remove(r.item, r.qty)
        ship.inventory:add(r.item, r.qty)
    end
    player.credits:add(balance)
    -- O estoque mudou: no landable, o preço da próxima troca já reflete isso
    Market.refreshPrices(trader)

    return true, balance
end

function Market.update()
end

return Market
