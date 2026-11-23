local Helper = require("spec.helper")

describe("WorldState", function()
  local SYSTEM = 1
  local PLANET = "Merle's Refuge"
  local star = { x = 0, y = 0 }

  before_each(function()
    Helper.setup()
    love.physics = { newCircleShape = function() return {} end }
    config.SpriteComponent = require("components.sprite")
    config.Landables = require("data.landables")
    config.CalendarData = require("data.calendar")
    config.Calendar = require("managers.calendar")
    config.WorldState = require("managers.world_state")
    config.WorldManager = require("managers.world_manager")
    config.LandableEntity = require("entities.landable")
    config.Entities.clear()
    config.WorldState.new(SYSTEM)
  end)

  local function spawnPlanet()
    config.LandableEntity(star, { PLANET }, SYSTEM)
    return config.Entities.getByTag("landable")[1]
  end

  -- Imita o que loadSystem faz ao sair do sistema
  local function leaveSystem()
    config.WorldManager.storeSystem()
    config.Entities.clear()
  end

  it("mantém preços e estoque do mercado ao sair e voltar ao sistema", function()
    local planet = spawnPlanet()
    config.MarketSystem.openLandable(planet)
    planet.inventory:add("Water", 7)
    config.MarketSystem.refreshPrices(planet)
    local prices = planet.market.prices

    leaveSystem()
    local again = spawnPlanet()
    assert.is_true(again.market.generated)
    assert.are.equal(planet.inventory.items["Water"], again.inventory.items["Water"])

    -- Sem tempo passado, o mercado não avança nem é sorteado de novo
    config.MarketSystem.openLandable(again)
    assert.are.same(prices, again.market.prices)
  end)

  it("mantém a fase orbital e faz o planeta andar com o relógio do mundo", function()
    local planet = spawnPlanet()
    local x0, y0 = planet.x, planet.y

    leaveSystem()
    local again = spawnPlanet()
    assert.are.equal(x0, again.x)
    assert.are.equal(y0, again.y)

    leaveSystem()
    config.WorldState.advance(100)
    local later = spawnPlanet()
    assert.are_not.equal(x0, later.x)
  end)

  it("começa do zero num jogo novo", function()
    local planet = spawnPlanet()
    config.MarketSystem.openLandable(planet)
    leaveSystem()
    config.WorldState.advance(50)

    config.WorldState.new(SYSTEM)

    assert.are.equal(0, config.WorldState.time())
    assert.is_nil(config.WorldState.landable(SYSTEM, PLANET))
  end)

  it("guarda só dados simples, prontos para um save", function()
    local planet = spawnPlanet()
    config.MarketSystem.openLandable(planet)
    leaveSystem()

    local function checkPlain(value, path)
      local t = type(value)
      assert.is_true(t == "number" or t == "string" or t == "boolean" or t == "table",
        path .. " é " .. t)
      if t == "table" then
        assert.is_nil(getmetatable(value), path .. " tem metatable")
        for k, v in pairs(value) do checkPlain(v, path .. "." .. tostring(k)) end
      end
    end
    checkPlain(config.WorldState.get(), "state")
  end)
end)
