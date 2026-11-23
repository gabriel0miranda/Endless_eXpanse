-- Economia dos mercados dos landables.
--
-- O estoque de cada mercado muda com o tempo por dois motivos:
--   1. Indústrias (data/industries.lua) consomem insumos e produzem bens.
--   2. O comércio de fundo, que representa os cargueiros que o jogo ainda não
--      simula, puxa cada estoque em direção ao seu alvo: importa o que falta e
--      exporta o que sobra.
-- O preço sai da razão entre estoque e alvo, multiplicada por uma flutuação
-- lenta e aleatória. Quem consome um item mantém o estoque abaixo do alvo e
-- paga mais por ele; quem produz, o contrário.
--
-- O mercado avança em passos de uma hora de jogo. Hoje o avanço acontece em
-- bloco quando o jogador pousa (Economy.catchUp); as funções trabalham só com
-- dados simples, para um futuro tick global poder chamá-las em todos os
-- mercados a cada hora.
local Economy = {}

local HOUR = 3600

-- Horas de fluxo das indústrias que formam o estoque-alvo de um item
Economy.TARGET_HOURS = 100
-- Fração da distância até o alvo que o comércio de fundo cobre por hora
Economy.RELAX_PER_HOUR = 0.02
-- Suavização da razão estoque/alvo: evita divisão por zero e limita o efeito
-- de poucas unidades num item que o mercado não usa
Economy.SMOOTHING = 50
Economy.MIN_FACTOR, Economy.MAX_FACTOR = 0.5, 2.5
-- Flutuação: passo aleatório por hora, puxada de volta para 1 e limitada
Economy.NOISE_STEP, Economy.NOISE_PULL = 0.02, 0.05
Economy.MIN_NOISE, Economy.MAX_NOISE = 0.8, 1.2
-- Depois de um mês fora o mercado já está perto do equilíbrio: simular mais
-- horas só gastaria tempo
Economy.MAX_CATCHUP_HOURS = 58 * 24
-- Horas simuladas na primeira visita, para o estoque sorteado se acomodar
Economy.WARMUP_HOURS = 72
-- Margem entre o que a estação paga e o que ela cobra (0.1 = ±10% do preço médio)
Economy.SPREAD = 0.1

-- Receitas de uma indústria. Uma indústria tem uma receita (`inputs` e
-- `outputs` direto na tabela) ou várias, independentes, em `recipes`.
local function recipes(key)
  local data = config.Industries[key]
  if not data then error("Indústria não definida: " .. tostring(key)) end
  local list = data.recipes or { data }
  for _, recipe in ipairs(list) do
    for _, items in ipairs({ recipe.inputs or {}, recipe.outputs or {} }) do
      for item in pairs(items) do
        if not config.Items[item] then
          error("Item não definido em data/items.lua: " .. item .. " (indústria " .. key .. ")")
        end
      end
    end
  end
  return list
end

-- Itens que as indústrias de um mercado consomem e produzem, como conjuntos
-- { [item] = true }. A interface do mercado destaca os consumidos.
function Economy.uses(marketData)
  local consumed, produced = {}, {}
  for key in pairs(marketData.industries or {}) do
    for _, recipe in ipairs(recipes(key)) do
      for item in pairs(recipe.inputs or {}) do consumed[item] = true end
      for item in pairs(recipe.outputs or {}) do produced[item] = true end
    end
  end
  return consumed, produced
end

local function volume(item)
  return config.Items[item].volume or 1
end

-- Estoque-alvo de cada item num mercado (marketData: `market` de um landable
-- em data/landables.lua). `stock` é opcional: serve para um item que nenhuma
-- indústria do local usa. Os demais itens têm alvo 0: o mercado compra, mas o
-- preço cai rápido.
function Economy.targets(marketData)
  local targets = {}
  for key, count in pairs(marketData.industries or {}) do
    for _, recipe in ipairs(recipes(key)) do
      for item, rate in pairs(recipe.inputs or {}) do
        targets[item] = (targets[item] or 0) + rate * count * Economy.TARGET_HOURS
      end
      for item, rate in pairs(recipe.outputs or {}) do
        targets[item] = (targets[item] or 0) + rate * count * Economy.TARGET_HOURS
      end
    end
  end
  for _, entry in ipairs(marketData.stock or {}) do
    local mid = (entry.min + entry.max) / 2
    targets[entry.item] = math.max(targets[entry.item] or 0, mid)
  end
  return targets
end

-- Estoque da primeira visita: em volta do alvo, ou na faixa de `stock`
function Economy.newStock(marketData)
  local items = {}
  local ranges = {}
  for _, entry in ipairs(marketData.stock or {}) do ranges[entry.item] = entry end
  for item, target in pairs(Economy.targets(marketData)) do
    local r = ranges[item]
    local qty = r and r.min + math.floor(love.math.random() * (r.max - r.min))
      or math.floor(target * (0.7 + love.math.random() * 0.6))
    if qty > 0 then items[item] = qty end
  end
  return items
end

local function usedVolume(items)
  local used = 0
  for item, qty in pairs(items) do used = used + volume(item) * qty end
  return used
end

local function add(items, item, qty)
  local total = (items[item] or 0) + qty
  items[item] = total > 0 and total or nil
end

-- Uma hora de produção: cada receita trabalha na fração que o seu insumo
-- mais escasso permite, e a produção para quando o armazém enche
local function runRecipe(recipe, count, items, capacity)
  local fraction = 1
  for item, rate in pairs(recipe.inputs or {}) do
    fraction = math.min(fraction, (items[item] or 0) / (rate * count))
  end
  if fraction <= 0 then return end
  for item, rate in pairs(recipe.inputs or {}) do
    add(items, item, -math.min(items[item] or 0, rate * count * fraction))
  end
  local free = capacity - usedVolume(items)
  for item, rate in pairs(recipe.outputs or {}) do
    local qty = math.min(rate * count * fraction, math.max(0, free) / volume(item))
    add(items, item, qty)
    free = free - qty * volume(item)
  end
end

local function runIndustries(marketData, items, capacity)
  for key, count in pairs(marketData.industries or {}) do
    for _, recipe in ipairs(recipes(key)) do
      runRecipe(recipe, count, items, capacity)
    end
  end
end

local function relax(items, targets)
  local seen = {}
  for item in pairs(targets) do seen[item] = true end
  for item in pairs(items) do seen[item] = true end
  for item in pairs(seen) do
    local qty = items[item] or 0
    add(items, item, ((targets[item] or 0) - qty) * Economy.RELAX_PER_HOUR)
  end
end

local function driftNoise(noise)
  for item in pairs(config.Items) do
    local n = noise[item] or 1
    n = n + (1 - n) * Economy.NOISE_PULL + (love.math.random() * 2 - 1) * Economy.NOISE_STEP
    noise[item] = math.max(Economy.MIN_NOISE, math.min(Economy.MAX_NOISE, n))
  end
end

-- Avança um mercado `hours` horas inteiras. state: { items, noise, capacity },
-- alterado no lugar. As quantidades ficam fracionárias durante a simulação e
-- são arredondadas no fim.
function Economy.advance(marketData, state, hours)
  local targets = Economy.targets(marketData)
  state.noise = state.noise or {}
  for _ = 1, math.min(hours, Economy.MAX_CATCHUP_HOURS) do
    runIndustries(marketData, state.items, state.capacity)
    relax(state.items, targets)
    driftNoise(state.noise)
  end
  for item, qty in pairs(state.items) do
    local whole = math.floor(qty + 0.5)
    state.items[item] = whole > 0 and whole or nil
  end
end

-- Fator de preço pela razão estoque/alvo: estoque abaixo do alvo encarece
function Economy.stockFactor(stock, target)
  local s = Economy.SMOOTHING
  local f = math.sqrt((target + s) / (stock + s))
  return math.max(Economy.MIN_FACTOR, math.min(Economy.MAX_FACTOR, f))
end

-- Preços de compra e venda de todos os itens. Compra e venda ficam sempre em
-- lados opostos do preço médio, então comprar e revender no mesmo lugar dá
-- prejuízo; o lucro vem de levar o item até onde vale mais.
function Economy.prices(marketData, items, noise)
  local targets = Economy.targets(marketData)
  local prices = {}
  for item, data in pairs(config.Items) do
    local mid = data.basePrice
      * Economy.stockFactor(items[item] or 0, targets[item] or 0)
      * ((noise or {})[item] or 1)
    prices[item] = {
      buy  = math.max(1, math.floor(mid * (1 - Economy.SPREAD))),  -- a estação paga ao jogador
      sell = math.max(2, math.ceil(mid * (1 + Economy.SPREAD))),   -- a estação cobra do jogador
    }
  end
  return prices
end

-- Horas inteiras entre `since` e `now` (segundos de jogo) e o instante até
-- onde elas vão, para a fração de hora restante não se perder
function Economy.elapsedHours(since, now)
  local hours = math.max(0, math.floor((now - since) / HOUR))
  return hours, since + hours * HOUR
end

return Economy
