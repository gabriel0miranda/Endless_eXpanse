local Playing = {}

local playerFlagShip = nil
local armedEntities = {}
local generatorEntities = {}
local landCooldown = 0
local mouseFadeTimer = 5

function Playing.onEnter(params)
  config.Input.pushContext("playing")
  config.Simulation.reset()
  config.InventoryUI.load()
  if params and params.resuming then
    landCooldown = 1.5
    print("Unfreezing")
    config.WorldManager:unfreeze()
    playerFlagShip = config.Entities.with("isFlagShip")[1]
    armedEntities = config.Entities.with("weapons")
    generatorEntities = config.Entities.with("generator")
  else
    landCooldown = 1.5
    playerFlagShip = config.Entities.with("isFlagShip")[1]
    armedEntities = config.Entities.with("weapons")
    generatorEntities = config.Entities.with("generator")
    if playerFlagShip.landedAt then
        config.WorldManager:freeze()
        config.GameState.switch("landed")
    end
    print("Entered space")
    mouseFadeTimer = config.MOUSE_FADE_TIMER
    config.Camera.x = playerFlagShip.rigidbody.body:getX()
    config.Camera.y = playerFlagShip.rigidbody.body:getY()
    config.Camera.scale = 0.2
    config.Camera.rotation = 0
    config.Camera.smoothSpeed = 8
    config.Camera.targetX = playerFlagShip.rigidbody.body:getX()
    config.Camera.targetY = playerFlagShip.rigidbody.body:getY()
  end
  -- Rota traçada no mapa: o próximo salto vira o alvo ao decolar e ao
  -- chegar por um buraco de minhoca
  if config.GameState.current == "playing" then
    config.Navigation.targetNextJump()
  end
end

function Playing.onExit()
  config.Input.popContext("playing")
  print("Exiting playing state")
end

-- Janelas modais em ordem de prioridade: a primeira aberta recebe a entrada.
-- Os módulos são resolvidos pelo nome em tempo de chamada porque config ainda
-- não existe quando este arquivo é carregado.
-- update = false: a janela não é atualizada pelo estado playing.
local MODALS = {
  { ui = "GalaxyMapUI",     update = true },
  { ui = "MissionLogUI",    update = false },
  { ui = "MapUI",           update = false },
  { ui = "TextInputUI",     update = false },
  { ui = "SelectUI",        update = true },
  { ui = "DialogueUI",      update = true },
  { ui = "PropertyUI",      update = true },
  { ui = "InventoryUI",     update = true },
  { ui = "CommunicationUI", update = true, openCheck = "CommunicationSystem" },
  { ui = "MarketUI",        update = true },
}

local function modalIsOpen(modal)
  return config[modal.openCheck or modal.ui].isOpen()
end

-- Repassa o evento para a janela modal do topo; devolve true se alguma o consumiu
local function dispatchToModal(method, ...)
  for _, modal in ipairs(MODALS) do
    if modalIsOpen(modal) then
      local ui = config[modal.ui]
      if ui[method] then ui[method](...) end
      return true
    end
  end
  return false
end

local function obj_pos(obj)
  return obj.x, obj.y
end

local function obj_radius(obj)
  return obj.radius or 10
end

local function rigidbody_pos(entity)
  return entity.rigidbody.body:getPosition()
end

local function shape_radius(entity)
  return (entity.sprite.shape and entity.sprite.shape:getRadius()) or 20
end

local function playerAlive()
  return playerFlagShip and playerFlagShip.rigidbody and playerFlagShip.rigidbody.body
    and not playerFlagShip.rigidbody.body:isDestroyed()
end

-- Um passo fixo do mundo (ver managers/simulation.lua). Tudo que aplica força,
-- move ou causa dano roda aqui; câmera, pouso e janelas rodam uma vez por frame.
local function simulationStep(dt)
  local ast_hash = config.SpatialHash.build(config.Entities.getByTag("asteroid"),rigidbody_pos,shape_radius,config.CELL_SIZE)

  local floatsome_hash = config.SpatialHash.build(config.Entities.getByTag("floatsome"),obj_pos,obj_radius,config.CELL_SIZE)

  local ship_hash = config.SpatialHash.build(config.Entities.getByTag("ship"),rigidbody_pos,shape_radius,config.CELL_SIZE)

  config.WorldState.advance(dt)
  config.ShipMovementSystem.update(playerFlagShip, dt)
  config.NpcAISystem.update(playerFlagShip, floatsome_hash, dt)
  config.GravityPullSystem.update(dt)
  config.LandableMovementSystem.update(dt)
  config.EnergySystem.update(generatorEntities,dt)
  config.WeaponSystem.update(armedEntities, dt)
  config.PickupSystem.update(dt,floatsome_hash)
  config.ProjectileSystem.update(ship_hash,ast_hash,dt)
  config.LaserSystem.update(dt)
  config.BeamSystem.update(dt)
  config.PulseSystem.update(ship_hash,ast_hash,dt)
  config.MineSystem.update(ship_hash,ast_hash,dt)
  config.ExplosionSystem.update(ship_hash, ast_hash, dt)
  config.DamageSystem.update(dt)
  config.FloatsomeSystem.update(dt)

  -- Nave destruída neste passo: para a simulação e deixa o update trocar de estado
  if not playerAlive() then return false end

  config.World:update(dt)
end

function Playing.update(dt)
  if landCooldown > 0 then
      landCooldown = landCooldown - dt
  end

  if mouseFadeTimer > 0 then
    mouseFadeTimer = mouseFadeTimer - dt
  elseif mouseFadeTimer <= 0 then
    love.mouse.setVisible(false)
    love.mouse.setRelativeMode(true)
  end

  if config.Input.state.paused then return end
  if not playerFlagShip or not playerFlagShip.rigidbody or not playerFlagShip.rigidbody.body or playerFlagShip.rigidbody.body:isDestroyed() then return end

  if config.Input.state.ui_map then
    config.MapUI.toggle(playerFlagShip)
  end
  if config.Input.state.ui_galaxy_map then
    if config.MapUI.isOpen() then config.MapUI.close() end
    config.GalaxyMapUI.toggle({ canTarget = true })
  end
  if config.Input.state.ui_missions then
    config.MissionLogUI.toggle()
  end

  config.TargetingSystem.update(playerFlagShip,dt)
  config.Simulation.advance(dt, simulationStep)

  -- Missões com prazo vencido falham em voo; o aviso vai para o feed
  for _, msg in ipairs(config.Missions.checkDeadlines(config.Calendar.now())) do
    config.CommunicationSystem.pushFeed(msg.text)
  end

  if not playerAlive() then
    config.GameState.switch("dead")
    return
  end
  -- config.Camera follow
  config.Camera:follow(playerFlagShip.rigidbody.body:getX(), playerFlagShip.rigidbody.body:getY())
  config.Camera:update(dt)

  -- Landing check
  for _, l in ipairs(config.Entities.getByTag("landable")) do
    local sx, sy = playerFlagShip.rigidbody.body:getX(), playerFlagShip.rigidbody.body:getY()
    local dx = sx - l.x
    local dy = sy - l.y
    if dx*dx + dy*dy < (l.radius + 40)^2 and config.Input.state.land and landCooldown <= 0 then
        playerFlagShip.landedAt = l
        config.WorldManager:freeze()
        config.GameState.switch("landed")
        config.Input.state.land = false
        return
    end
  end

  if config.Input.state.ui_mainmenu then
    config.GameState.switch("mainmenu")
  end

  if config.Input.state.ui_inventory then
    config.InventoryUI.toggle(playerFlagShip,{title = "Your Ship"} )
  end

  if config.Input.state.ui_properties then
    config.PropertyUI.toggle()
  end

  for _, modal in ipairs(MODALS) do
    if modal.update and modalIsOpen(modal) then
      config[modal.ui].update(dt)
    end
  end

  if config.Input.state.ui_comm and config.TargetingSystem.current then
    config.CommunicationUI.openComm(playerFlagShip)
  end
  config.CommunicationSystem.update(playerFlagShip,dt)
end

function Playing.textinput(t)
    if config.TextInputUI.isOpen()then
        config.TextInputUI.textinput(t)
    end
end

function Playing.keypressed(key)
  if dispatchToModal("keypressed", key) then return end
  config.TargetingSystem.keypressed(key)
end

function Playing.mousemoved(x,y,dx,dy,istouch)
  love.mouse.setVisible(true)
  love.mouse.setRelativeMode(false)
  mouseFadeTimer = config.MOUSE_FADE_TIMER
end

function Playing.mousepressed(mx, my, button)
  if dispatchToModal("mousepressed", mx, my, button) then return end
  config.TargetingSystem.mousepressed(mx, my, button)
end

function Playing.wheelmoved(dx, dy)
  dispatchToModal("wheelmoved", dx, dy)
end

function Playing.draw()
  if config.GalaxyMapUI.isOpen() then
    config.GalaxyMapUI.draw()
  elseif config.MapUI.isOpen() then
    config.MapUI.draw(playerFlagShip)
  else
    config.RenderingSystem.draw(playerFlagShip, config.Camera)
  end
  if not config.GalaxyMapUI.isOpen() then
    config.MissionLogUI.draw()
  end
end

return Playing
