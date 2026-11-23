-- Ambiente mínimo para testar lógica pura fora do LÖVE: substitui só o que
-- os módulos testados usam de `love` e monta um `config` com os módulos reais.
local Helper = {}

function Helper.setup()
  _G.love = {
    math = { random = math.random },
  }

  _G.config = {
    Input = {
      state = {},
      hidePulses = function() return {} end,
      restorePulses = function() end,
    },
    Items = require("data.items"),
    Industries = require("data.industries"),
    Starts = require("data.starts"),
    Entities = require("entities"),
    InventoryComponent = require("components.inventory"),
    CreditsComponent = require("components.credits"),
    PropertyComponent = require("components.property"),
    DeepCopy = require("utils.deep_copy"),
  }
  config.Economy = require("systems.economy")
  config.MarketSystem = require("systems.market")
  config.PlayerEntity = require("entities.player")
end

return Helper
