local Helper = require("spec.helper")

describe("Triggers", function()
  local shown

  before_each(function()
    Helper.setup()
    config.WorldState = require("managers.world_state")
    config.Triggers = require("managers.triggers")
    config.WorldState.new(5, 0)
    config.Entities.clear()
    config.PlayerEntity(config.Starts["Lost Peregrine"], "Teste")

    -- DialogueUI falso: guarda as mensagens; close() imita o jogador fechando
    shown = {}
    config.DialogueUI = {
      open = function(opts) shown[#shown + 1] = opts end,
    }
    config.TriggerData = {
      a_start = { event = "depart", once = true, conditions = { start = "Lost Peregrine", landable = "Lilium" }, text = "A" },
      b_other = { event = "depart", once = true, conditions = { start = "Iron Baller" }, text = "B" },
      c_land  = { event = "land", conditions = { system = 5 }, text = "C" },
      d_never = { event = "depart", conditions = { chance = 0 }, text = "D" },
    }
  end)

  local function close()
    local opts = table.remove(shown, 1)
    opts.onConfirm(nil)
  end

  it("só dispara gatilhos do evento cujas condições valem", function()
    local list = config.Triggers.matching("depart", { landable = "Lilium" })
    assert.are.equal(1, #list)
    assert.are.equal("a_start", list[1].id)
    assert.are.equal(0, #config.Triggers.matching("depart", { landable = "Merle's Refuge" }))
  end)

  it("segura a ação até o jogador fechar a mensagem", function()
    local departed = false
    assert.is_true(config.Triggers.fire("depart", { landable = "Lilium" }, function() departed = true end))
    assert.are.equal("A", shown[1].text)
    assert.is_false(departed)
    close()
    assert.is_true(departed)
  end)

  it("não repete um gatilho once, nem depois de save e load", function()
    config.Triggers.fire("depart", { landable = "Lilium" })
    close()
    local saved = config.WorldState.get()
    config.WorldState.load(saved)

    local departed = false
    assert.is_false(config.Triggers.fire("depart", { landable = "Lilium" }, function() departed = true end))
    assert.is_true(departed)  -- sem mensagem, a ação segue na hora
  end)

  it("não conta o gatilho se a mensagem não foi fechada", function()
    config.Triggers.fire("depart", { landable = "Lilium" })
    shown = {}  -- o jogador cancelou (Esc): onConfirm não roda
    assert.are.equal(1, #config.Triggers.matching("depart", { landable = "Lilium" }))
  end)

  it("repete gatilhos sem once e mostra vários em sequência", function()
    config.TriggerData.c_land2 = { event = "land", text = "C2" }
    config.Triggers.fire("land", {})
    assert.are.equal("C", shown[1].text)
    close()
    assert.are.equal("C2", shown[1].text)
    close()
    config.Triggers.fire("land", {})
    assert.are.equal(1, #shown)
    assert.are.equal(1, config.WorldState.triggerCount("c_land"))
  end)
end)

describe("Dados dos gatilhos", function()
  before_each(function() Helper.setup() end)

  it("usam eventos, cenários, landables e sistemas que existem", function()
    local events = { depart = true, land = true }
    local landables, systems, starts = require("data.landables"), require("data.systems"), require("data.starts")
    for id, t in pairs(require("data.triggers")) do
      assert.is_true(events[t.event] ~= nil, id .. ": evento " .. tostring(t.event))
      assert.is_string(t.text, id .. ": sem texto")
      local c = t.conditions or {}
      if c.start then assert.is_not_nil(starts[c.start], id .. ": start " .. c.start) end
      if c.landable then assert.is_not_nil(landables[c.landable], id .. ": landable " .. c.landable) end
      if c.system then assert.is_not_nil(systems[c.system], id .. ": sistema " .. c.system) end
    end
  end)
end)
