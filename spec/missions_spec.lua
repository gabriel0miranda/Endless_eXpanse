local Helper = require("spec.helper")

describe("Missões", function()
  local Missions, ship, player
  local DAY = 24 * 3600

  -- Avança o relógio do mundo em `days` dias de jogo
  local function passDays(days)
    config.WorldState.advance(config.Calendar.toSimSeconds(days * DAY))
  end

  -- Substitui as ofertas do bar de Lírio (sistema 5) por `list`
  local function setOffers(list)
    Missions.offers(5, "Lilium", 100)
    config.WorldState.missions().offers["5:Lilium"].list = list
  end

  local function delivery(fields)
    local o = {
      kind = "delivery", title = "Entrega", text = "", faction = "Bhikku",
      origin = { system = 5, landable = "Lilium" },
      dest = { system = 4, landable = "Flutura" },
      item = "Water", quantity = 5, reward = 900,
      deadline = config.Calendar.now() + 2 * DAY,
    }
    for k, v in pairs(fields or {}) do o[k] = v end
    return o
  end

  before_each(function()
    Helper.setup()
    config.Systems = require("data.systems")
    config.Landables = require("data.landables")
    config.Ships = require("data.ships")
    config.CalendarData = require("data.calendar")
    config.MissionData = require("data.missions")
    config.WorldState = require("managers.world_state")
    config.Calendar = require("managers.calendar")
    config.Missions = require("systems.missions")
    Missions = config.Missions
    config.Entities.clear()
    config.WorldState.new(5, 0)
    player = config.PlayerEntity(config.Starts["Lost Peregrine"], "Teste")
    player.credits.amount = 0
    ship = { type = "PP-2340", isFlagShip = true, inventory = config.InventoryComponent(100, {}) }
  end)

  it("usa a facção de maior peso do sistema como contratante", function()
    assert.are.equal("Bhikku", Missions.landableFaction(5, "Lilium"))
    assert.are.equal("Ballestra", Missions.landableFaction(4, "Flutura"))
  end)

  it("gera ofertas completas e as mantém até o fim do período", function()
    for _ = 1, 20 do
      config.WorldState.missions().offers = {}
      local offers = Missions.offers(5, "Lilium", 100)
      assert.is_true(#offers >= 1 and #offers <= config.MissionData.offers.max)
      for _, o in ipairs(offers) do
        assert.is_true(o.reward > 0)
        assert.is_nil(o.title:find("{", 1, true))
        assert.is_nil(o.text:find("{", 1, true))
        assert.is_true(o.deadline > config.Calendar.now())
      end
    end
    local first = Missions.offers(5, "Lilium", 100)
    assert.are.equal(first, Missions.offers(5, "Lilium", 100))
    passDays(1)
    assert.are_not.equal(first, Missions.offers(5, "Lilium", 100))
  end)

  it("põe a carga da entrega no porão e recusa sem espaço", function()
    setOffers({ delivery({ quantity = 500 }), delivery({ quantity = 5 }) })
    local ok, err = Missions.accept(5, "Lilium", 1, ship)  -- 500 de água não cabem em 100
    assert.is_false(ok)
    assert.is_string(err)
    assert.is_true(Missions.accept(5, "Lilium", 2, ship))
    assert.are.equal(5, ship.inventory.items.Water)
    assert.are.equal(1, #Missions.active())
    assert.is_true(config.WorldState.isRevealed(4))
  end)

  it("paga a entrega no destino e aumenta a reputação", function()
    setOffers({ delivery() })
    Missions.accept(5, "Lilium", 1, ship)
    assert.are.same({}, Missions.onLand(4, "Iron Ball", ship))  -- outro landable
    local msgs = Missions.onLand(4, "Flutura", ship)
    assert.are.equal("Missão cumprida", msgs[1].speaker)
    assert.are.equal(900, player.credits.amount)
    assert.are.equal(0, ship.inventory.items.Water or 0)
    assert.are.equal(1, config.WorldState.reputation("Bhikku"))
    assert.are.equal(0, #Missions.active())
  end)

  it("falha no prazo, mantém a carga e derruba a reputação", function()
    setOffers({ delivery() })
    Missions.accept(5, "Lilium", 1, ship)
    passDays(3)
    local msgs = Missions.onLand(4, "Flutura", ship)
    assert.are.equal("Missão falhou", msgs[1].speaker)
    assert.are.equal(0, player.credits.amount)
    assert.are.equal(5, ship.inventory.items.Water)
    assert.are.equal(-3, config.WorldState.reputation("Bhikku"))
  end)

  it("espera a encomenda completa", function()
    setOffers({ delivery({ kind = "procure", dest = { system = 5, landable = "Lilium" }, quantity = 4 }) })
    Missions.accept(5, "Lilium", 1, ship)
    ship.inventory:add("Water", 3)
    local msgs = Missions.onLand(5, "Lilium", ship)
    assert.are.equal(1, #Missions.active())
    assert.truthy(msgs[1].text:find("Faltam 1"))
    ship.inventory:add("Water", 1)
    Missions.onLand(5, "Lilium", ship)
    assert.are.equal(0, #Missions.active())
    assert.are.equal(0, ship.inventory.items.Water or 0)
  end)

  it("confere os beliches para passageiros", function()
    setOffers({
      delivery({ kind = "passengers", item = nil, quantity = nil, passengers = 3 }),
      delivery({ kind = "passengers", item = nil, quantity = nil, passengers = 2 }),
    })
    assert.is_true(Missions.accept(5, "Lilium", 1, ship))  -- PP-2340: 4 beliches
    assert.is_false(Missions.accept(5, "Lilium", 1, ship))
    Missions.onLand(4, "Flutura", ship)
    assert.are.equal(900, player.credits.amount)
  end)

  it("conta só os piratas destruídos pela nave ativa no sistema da caça", function()
    setOffers({ delivery({ kind = "bounty", system = 4, count = 2, kills = 0,
      dest = { system = 5, landable = "Lilium" } }) })
    Missions.accept(5, "Lilium", 1, ship)
    -- Como no jogo: a facção fica no NPC dono da nave
    local pirate = {}
    config.Entities.create("npc", { profile = { faction = "Pirate" }, ship = pirate })
    local miner = { profile = { faction = "Pacifists" } }
    config.WorldState.setCurrentSystem(4)
    Missions.onShipDestroyed(pirate, { isFlagShip = nil })  -- outro NPC matou
    Missions.onShipDestroyed(miner, ship)
    Missions.onShipDestroyed(pirate, ship)
    assert.are.equal(1, Missions.active()[1].kills)
    local msgs = Missions.onShipDestroyed(pirate, ship)
    assert.truthy(msgs[1].text:find("Volte a"))
    Missions.onShipDestroyed(pirate, ship)
    assert.are.equal(2, Missions.active()[1].kills)
    Missions.onLand(5, "Lilium", ship)
    assert.are.equal(900, player.credits.amount)
    assert.are.equal(config.MissionData.reputation.bounty, config.WorldState.reputation("Bhikku"))
  end)

  it("cumpre a missão de história ao entrar no sistema, uma vez só", function()
    assert.is_true(Missions.startStory("reach_eye"))
    assert.is_false(Missions.startStory("reach_eye"))
    assert.is_nil(Missions.abandon(Missions.active()[1].id))
    assert.are.same({}, Missions.onSystemEntered(4))
    local msgs = Missions.onSystemEntered(6)
    assert.are.equal("Missão cumprida", msgs[1].speaker)
    assert.is_false(Missions.startStory("reach_eye"))
  end)

  it("desistir conta como falha", function()
    setOffers({ delivery() })
    Missions.accept(5, "Lilium", 1, ship)
    local msg = Missions.abandon(Missions.active()[1].id)
    assert.are.equal("Missão falhou", msg.speaker)
    assert.are.equal(-3, config.WorldState.reputation("Bhikku"))
    assert.are.equal(5, ship.inventory.items.Water)
  end)

  it("todo modelo de trabalho e missão de história tem os campos usados", function()
    for kind, job in pairs(config.MissionData.jobs) do
      assert.is_string(job.label, kind)
      assert.is_number(job.weight, kind)
      assert.is_string(job.title, kind)
      assert.is_string(job.text, kind)
    end
    for key, story in pairs(config.MissionData.story) do
      assert.is_not_nil(config.Systems[story.system], key)
    end
    for id, trigger in pairs(require("data.triggers")) do
      if trigger.startMission then
        assert.is_not_nil(config.MissionData.story[trigger.startMission], id)
      end
    end
  end)
end)
