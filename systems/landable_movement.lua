local LandableMovement = {}

-- A posição orbital é calculada a partir do relógio do mundo (forma fechada),
-- não acumulada frame a frame: assim ela não deriva e é a mesma ao voltar
-- para o sistema ou carregar um save.
function LandableMovement.update(_dt)
  local starList = config.Entities.getByTag("star")
  local landableList = config.Entities.getByTag("landable")
  local time = config.WorldState.time()
  for _, landable in ipairs(landableList) do
    if not landable.toSystem then
      if landable.orbitSpeed > 0 then
        landable.orbitAngle = landable.orbitPhase + landable.orbitSpeed * time
        landable.x = starList[1].x + landable.orbitRadius * math.cos(landable.orbitAngle)
        landable.y = starList[1].y + landable.orbitRadius * math.sin(landable.orbitAngle)
      end
    end
  end
end

return LandableMovement
