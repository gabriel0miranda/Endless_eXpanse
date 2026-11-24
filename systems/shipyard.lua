local Shipyard = {}

-- Set Flagship
function Shipyard.setFlagShip(player, fleet)
  if not fleet or fleet.flagShip then return end
  -- Troca flagship: desmarca a atual, marca a selecionada
  for _, e in pairs(player.property.properties) do
      e.flagShip = false
  end
  fleet.flagShip = true
  return fleet
end
-- Retorna lista ordenada da frota do jogador
function Shipyard.getFleet(player)
  if not player or not player.property then return {} end
  local list = {}
  for _, property in pairs(player.property.properties) do
    if property.ship then
      table.insert(list, property)
    end
  end
  table.sort(list, function(a, b)
    if a.flagShip ~= b.flagShip then return a.flagShip end
    return (a.name or "") < (b.name or "")
  end)
  return list
end

-- Retorna lista ordenada do estoque da estação
function Shipyard.getStationStock(station)
    if not station then return {} end
    local data = config.Landables[station.name]
    local sy   = data and data.shipyard
    if not sy or not sy.stock then return {} end
    local list = {}
    for _, shipType in ipairs(sy.stock) do
        local def = config.Ships[shipType]
        if def then
            table.insert(list, { shipType = shipType, def = def })
        end
    end
    return list
end

-- Função auxiliar para calcular preço de revenda (70% do valor)
function Shipyard.getSellPrice(shipType)
    local def = config.Ships[shipType]
    return math.floor(def.price * 0.8)
end

function Shipyard.buyShip(player, shipType, customName)
  local def = config.Ships[shipType]

  if player.credits.amount < def.price then
      return false, "Insufficient credits!"
  end

  -- Cria a entidade da nave. 
  -- Note: x, y em (0,0) pois ela está "guardada" no player
  local newShip = { ship=true,
                    flagShip=false,
                    name=customName,
                    type=shipType,
                    cargo = {}
                  }
  local added, err = player.property:add(newShip)
  if not added then
      return false, err
  end
  player.credits.amount = player.credits.amount - def.price
  return true, "Ship bought"
end

-- A nave tem alguma carga no porão?
function Shipyard.hasCargo(shipEntity)
  for _, qty in pairs(shipEntity.cargo or {}) do
    if qty > 0 then return true end
  end
  return false
end

-- O vendedor lança uma moeda para decidir se avisa que a nave à venda ainda
-- tem carga. Sem aviso, a carga vai junto com a nave. `roll` (0 a 1) é
-- opcional e serve aos testes.
function Shipyard.sellerWarnsCargo(shipEntity, roll)
  if not Shipyard.hasCargo(shipEntity) then return false end
  return (roll or love.math.random()) < 0.5
end

-- Vender a nave ativa passa o posto para outra nave da frota. Sem nave
-- ativa a decolagem não tem o que montar e o jogo congela.
function Shipyard.sellShip(player, shipEntity)
  local fleet = Shipyard.getFleet(player)
  if #fleet <= 1 then
      return false, "Não dá para vender a única nave da frota."
  end

  local price = Shipyard.getSellPrice(shipEntity.type)
  player.credits.amount = player.credits.amount + price
  player.property:remove(shipEntity)

  if shipEntity.flagShip then
      shipEntity.flagShip = false
      Shipyard.setFlagShip(player, Shipyard.getFleet(player)[1])
  end

  return true, "Ship sold"
end

return Shipyard
