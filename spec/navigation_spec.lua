local Helper = require("spec.helper")

describe("Navigation", function()
  -- 1 ⇄ 2 ⇄ 3 ⇄ 4, 2 → 5 (mão única), 6 isolado
  local SYSTEMS = {
    [1] = { name = "A", wormholes = { { name = "To B", toSystem = 2 } } },
    [2] = { name = "B", wormholes = { { name = "To A", toSystem = 1 }, { name = "To C", toSystem = 3 }, { name = "To E", toSystem = 5 } } },
    [3] = { name = "C", wormholes = { { name = "To B", toSystem = 2 }, { name = "To D", toSystem = 4 } } },
    [4] = { name = "D", wormholes = { { name = "To C", toSystem = 3 } } },
    [5] = { name = "E", wormholes = {} },
    [6] = { name = "F", wormholes = {} },
  }

  before_each(function()
    Helper.setup()
    config.Systems = SYSTEMS
    config.WorldState = require("managers.world_state")
    config.Navigation = require("systems.navigation")
    config.WorldState.new(1, 0)
  end)

  it("mostra visitados, vizinhos deles e sistemas revelados", function()
    config.WorldState.reveal(6)
    local nav = config.Navigation
    assert.are.equal("visited", nav.knowledge(1))
    assert.are.equal("neighbor", nav.knowledge(2))
    assert.is_nil(nav.knowledge(3))
    assert.are.equal("revealed", nav.knowledge(6))
  end)

  it("conhece um buraco de minhoca só a partir de um sistema visitado", function()
    config.WorldState.setCurrentSystem(2)
    assert.are.equal("neighbor", config.Navigation.knowledge(5))
    assert.are.same({ { from = 1, to = 2 }, { from = 2, to = 3 }, { from = 2, to = 5 } }, config.Navigation.knownLinks())
  end)

  it("traça a rota mais curta só pelo que o jogador conhece", function()
    config.WorldState.setCurrentSystem(2)
    config.WorldState.setCurrentSystem(1)
    assert.are.same({ 1, 2, 3 }, config.Navigation.route(1, 3))
    assert.is_nil(config.Navigation.route(1, 4))      -- C nunca foi visitado
    config.WorldState.setCurrentSystem(3)
    assert.are.same({ 3, 2, 1 }, config.Navigation.route(3, 1))
    assert.are.same({ 1, 2, 3, 4 }, config.Navigation.route(1, 4))
    assert.is_nil(config.Navigation.route(1, 6))
    assert.are.equal("To C", config.Navigation.wormholeTo(2, 3))
  end)

  it("deduz os visitados de um save anterior ao mapa", function()
    config.WorldState.load({ time = 0, currentSystemId = 3, systems = { ["1"] = { landables = {} } } })
    assert.is_true(config.WorldState.isVisited(1))
    assert.is_true(config.WorldState.isVisited(3))
    assert.is_false(config.WorldState.isVisited(2))
    assert.is_false(config.WorldState.isRevealed(6))
  end)
end)

describe("Dados do mapa", function()
  before_each(function() Helper.setup() end)

  it("todo sistema tem posição no mapa e buracos de minhoca para sistemas que existem", function()
    local systems = require("data.systems")
    for id, sys in pairs(systems) do
      assert.is_number(sys.mapX, sys.name .. ": sem mapX")
      assert.is_number(sys.mapY, sys.name .. ": sem mapY")
      for _, w in ipairs(sys.wormholes or {}) do
        assert.is_not_nil(systems[w.toSystem], sys.name .. ": " .. w.name .. " leva a um sistema inexistente")
      end
    end
  end)

  it("os sistemas revelados pelos starts existem", function()
    local systems = require("data.systems")
    for key, start in pairs(require("data.starts")) do
      for _, id in ipairs(start.known_systems or {}) do
        assert.is_not_nil(systems[id], key .. ": sistema revelado inexistente " .. id)
      end
    end
  end)
end)
