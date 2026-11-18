local Helper = require("spec.helper")

describe("Simulation", function()
  local Simulation
  local STEP

  before_each(function()
    Helper.setup()
    Simulation = require("managers.simulation")
    Simulation.reset()
    STEP = Simulation.STEP
  end)

  local function countSteps(dt)
    local dts = {}
    local n = Simulation.advance(dt, function(stepDt) table.insert(dts, stepDt) end)
    return n, dts
  end

  it("roda um passo por frame a 60 FPS, mesmo com jitter do vsync", function()
    for i = 1, 600 do
      local jitter = (i % 2 == 0) and 0.0008 or -0.0008
      assert.are.equal(1, (countSteps(STEP + jitter)))
    end
  end)

  it("transforma um frame lento em vários passos do mesmo tamanho", function()
    local n, dts = countSteps(0.05)
    assert.are.equal(3, n)
    for _, d in ipairs(dts) do assert.are.equal(STEP, d) end
  end)

  it("limita os passos de um engasgo muito longo", function()
    local n = countSteps(2.0)
    assert.is_true(n <= 7)
  end)

  it("cancela os passos restantes quando o step devolve false", function()
    local calls = 0
    Simulation.advance(0.05, function() calls = calls + 1; return false end)
    assert.are.equal(1, calls)
  end)

  it("entrega os pulses de input só ao primeiro passo do frame", function()
    config.Input = {
      state = {},
      hidePulses = function()
        config.Input.state.ship_generator_switch_mode = false
        return { ship_generator_switch_mode = true }
      end,
      restorePulses = function(h)
        for a in pairs(h) do config.Input.state[a] = true end
      end,
    }
    config.Input.state.ship_generator_switch_mode = true

    local seen = {}
    Simulation.advance(0.05, function()
      table.insert(seen, config.Input.state.ship_generator_switch_mode)
    end)

    assert.are.same({ true, false, false }, seen)
    assert.is_true(config.Input.state.ship_generator_switch_mode)
  end)
end)
