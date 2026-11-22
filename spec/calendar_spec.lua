local Helper = require("spec.helper")

describe("Calendar", function()
  local Calendar
  local HOUR = 3600

  before_each(function()
    Helper.setup()
    -- Cópia sem nomes de mês: os testes usam o formato numérico, salvo quando dizem o contrário
    config.CalendarData = config.DeepCopy(require("data.calendar"))
    config.CalendarData.monthNames = {}
    config.WorldState = require("managers.world_state")
    config.Calendar = require("managers.calendar")
    Calendar = config.Calendar
  end)

  local function at(year, month, day, hour, minute)
    return Calendar.toSeconds({ year = year, month = month, day = day, hour = hour, minute = minute })
  end

  it("converte data em segundos e de volta", function()
    for _, d in ipairs({
      { year = 768, month = 1,  day = 1,  hour = 8,  minute = 0 },
      { year = 768, month = 11, day = 58, hour = 23, minute = 59 },
      { year = 0,   month = 6,  day = 30, hour = 12, minute = 30 },
    }) do
      assert.are.same(d, Calendar.fromSeconds(Calendar.toSeconds(d)))
    end
  end)

  it("tem ano de 11 meses de 58 dias", function()
    assert.are.equal(638 * 24 * HOUR, at(769, 1, 1) - at(768, 1, 1))
    assert.are.equal(58 * 24 * HOUR, at(768, 2, 1) - at(768, 1, 1))
    -- o dia seguinte ao último dia do ano é 01/01 do ano seguinte
    assert.are.same({ year = 769, month = 1, day = 1, hour = 0, minute = 0 },
      Calendar.fromSeconds(at(768, 11, 58) + 24 * HOUR))
  end)

  it("formata com números ou com o nome do mês", function()
    assert.are.equal("01/03/768 E.G. 09:05", Calendar.format(at(768, 3, 1, 9, 5)))
    config.CalendarData.monthNames = { "Primo", "Secundo", "Tertio" }
    assert.are.equal("1 Tertio 768 E.G.", Calendar.formatDate(at(768, 3, 1, 9, 5)))
  end)

  it("avança 1 minuto de jogo por segundo real em voo", function()
    config.WorldState.new(1, at(768, 1, 1, 8))
    config.WorldState.advance(60)
    assert.are.equal("01/01/768 E.G. 09:00", Calendar.format(Calendar.now()))
  end)

  it("descansa até as 06:00, com pelo menos 4 horas de sono", function()
    assert.are.equal(22 * HOUR, Calendar.restDuration(at(768, 1, 1, 8)))   -- 08:00 → 06:00 do dia seguinte
    assert.are.equal(5 * HOUR,  Calendar.restDuration(at(768, 1, 1, 1)))   -- 01:00 → 06:00 do mesmo dia
    assert.are.equal(27 * HOUR, Calendar.restDuration(at(768, 1, 1, 3)))   -- 03:00: só 3 h até as 06:00, dorme até o outro dia
  end)
end)

describe("WorldState.resetSystem", function()
  before_each(function()
    Helper.setup()
    config.WorldState = require("managers.world_state")
    config.WorldState.new(1, 0)
  end)

  it("renova asteroides e mercados, mas mantém a órbita dos planetas", function()
    config.WorldState.setLandable(1, "Iron Ball", { phase = 1.5, market = { prices = {} } })
    local sys = config.WorldState.system(1)
    sys.asteroids = { { x = 1 } }
    sys.storedAt = 10

    config.WorldState.resetSystem(1)

    assert.is_nil(sys.asteroids)
    assert.is_nil(config.WorldState.landable(1, "Iron Ball").market)
    assert.are.equal(1.5, config.WorldState.landable(1, "Iron Ball").phase)
  end)

  it("aceita saves anteriores ao calendário", function()
    config.WorldState.load({ version = 1, time = 5, currentSystemId = 1, systems = {} })
    assert.are.equal(0, config.WorldState.startDate())
  end)
end)
