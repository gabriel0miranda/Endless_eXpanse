local Dead = {}

-- ─────────────────────────────────────────
-- Cores  (tema marrom/âmbar — igual ao market_ui)
-- ─────────────────────────────────────────

local C = {
    bg          = {0.06, 0.03, 0.01, 1},
    bgBtn       = {0.08, 0.04, 0.02, 1},
    bgBtnHover  = {0.14, 0.07, 0.02, 1},
    border      = {0.23, 0.13, 0.05, 1},
    borderAccent= {0.75, 0.38, 0.13, 1},
    borderDanger= {0.45, 0.12, 0.06, 1},
    textNormal  = {0.78, 0.62, 0.42, 1},
    textBright  = {0.92, 0.78, 0.58, 1},
    textMuted   = {0.38, 0.22, 0.10, 1},
    textActive  = {0.88, 0.60, 0.22, 1},
    textDanger  = {0.87, 0.30, 0.18, 1},
    keyNormal   = {0.38, 0.22, 0.10, 1},
    keyHover    = {0.75, 0.38, 0.13, 1},
    keyDanger   = {0.87, 0.30, 0.18, 1},
}

-- ─────────────────────────────────────────
-- Estrelas (geradas uma vez no onEnter)
-- ─────────────────────────────────────────

local stars = {}

local function generateStars()
    stars = {}
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    for i = 1, 140 do
        table.insert(stars, {
            x = love.math.random() * sw,
            y = love.math.random() * sh,
            r = love.math.random() * 1.5 + 0.3,
            a = 0.2 + love.math.random() * 0.5,
        })
    end
end

-- ─────────────────────────────────────────
-- Botões
-- ─────────────────────────────────────────

local BTN_W   = 240
local BTN_H   = 34
local BTN_GAP = 4

local buttons = {
    { key = "1", label = "Menu",      action = "menu", danger = false },
    { key = "2", label = "Sair",      action = "quit", danger = true  },
}

local hoveredBtn = 1

-- ─────────────────────────────────────────
-- Fade-in (segundos desde a morte)
-- Texto e botões aparecem primeiro; depois o espaço vai escurecendo devagar.
-- ─────────────────────────────────────────

local UI_FADE_START = 0.3
local UI_FADE_END   = 2.0
local BG_FADE_START = 1.5
local BG_FADE_END   = 9.0

local elapsed = 0
local fade    = 1  -- multiplicador de alpha aplicado por setColor

local function fadeProgress(startT, endT)
  local t = math.min(1, math.max(0, (elapsed - startT) / (endT - startT)))
  return t * t * (3 - 2 * t)  -- smoothstep
end

local function inputReady()
  return elapsed >= UI_FADE_END
end

local function executeAction(action)
  if action == "menu" then
    config.GameState.switch("mainmenu")
  elseif action == "quit" then
      love.event.quit()
  end
end

-- ─────────────────────────────────────────
-- Geometria
-- ─────────────────────────────────────────

local G = {}

local function recalcGeometry()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    G.titleX = sw / 2
    G.titleY = sh / 2 - 140

    local dividerH = 18
    local totalH   = #buttons * BTN_H + (#buttons - 1) * BTN_GAP + dividerH
    G.btnStartX = sw / 2 - BTN_W / 2
    G.btnStartY = sh / 2 - totalH / 2 + 40

    G.btnY = {}
    local curY = G.btnStartY
    for i = 1, #buttons do
        G.btnY[i] = curY
        curY = curY + BTN_H + BTN_GAP
        if i == 2 then
            curY = curY + dividerH
        end
    end

    G.dividerY = G.btnY[2] + BTN_H + BTN_GAP / 2 + 4

    -- Planeta decorativo (canto superior direito)
    G.planetX = sw * 0.82
    G.planetY = sh * 0.22
    G.planetR = 55

    G.footerY = sh - 24
end

-- ─────────────────────────────────────────
-- Gamestate hooks
-- ─────────────────────────────────────────

function Dead.onEnter()
    config.Input.pushContext("dead")
    love.mouse.setVisible(true)
    love.mouse.setRelativeMode(false)
    generateStars()
    recalcGeometry()
    hoveredBtn = 1
    elapsed = 0
    config.TargetingSystem.current = nil
    config.Simulation.reset()
end

function Dead.onExit()
    config.Input.popContext("dead")
    -- As entidades ficam vivas durante o fade (o espaço aparece ao fundo)
    config.Entities.clear()
end

local function rigidbody_pos(entity)
  return entity.rigidbody.body:getPosition()
end

local function shape_radius(entity)
  return (entity.sprite.shape and entity.sprite.shape:getRadius()) or 20
end

-- Mantém o espaço em movimento atrás da tela de morte: física, órbitas e explosões.
-- Um passo fixo, chamado por config.Simulation.advance.
local function worldStep(dt)
  local ship_hash = config.SpatialHash.build(config.Entities.getByTag("ship"),rigidbody_pos,shape_radius,config.CELL_SIZE)
  local ast_hash  = config.SpatialHash.build(config.Entities.getByTag("asteroid"),rigidbody_pos,shape_radius,config.CELL_SIZE)
  config.LandableMovementSystem.update(dt)
  config.ProjectileSystem.update(ship_hash, ast_hash, dt)
  config.LaserSystem.update(dt)
  config.BeamSystem.update(dt)
  config.ExplosionSystem.update(ship_hash, ast_hash, dt)
  config.DamageSystem.update(dt)
  config.World:update(dt)
end

function Dead.update(dt)
    elapsed = elapsed + dt
    if elapsed < BG_FADE_END then
        config.Simulation.advance(dt, worldStep)
    end

    local mx, my = love.mouse.getPosition()
    for i = 1, #buttons do
        local bx = G.btnStartX
        local by = G.btnY[i]
        if mx >= bx and mx <= bx + BTN_W and my >= by and my <= by + BTN_H then
            hoveredBtn = i
            break
        end
    end
end

function Dead.mousepressed(mx, my, button)
    if button ~= 1 or not inputReady() then return end
    for i = 1, #buttons do
        local bx = G.btnStartX
        local by = G.btnY[i]
        if mx >= bx and mx <= bx + BTN_W and my >= by and my <= by + BTN_H then
            executeAction(buttons[i].action)
            return
        end
    end
end

function Dead.wheelmoved(dx, dy)
end

function Dead.keypressed(key)
  if not inputReady() then return end
  for _, btn in ipairs(buttons) do
    if key == btn.key then
      executeAction(btn.action)
      return
    end
  end
  if key == "return" then
    executeAction(buttons[hoveredBtn > 0 and hoveredBtn or 1].action)
  end
  if key == "escape" then
    love.event.quit()
  end
  if key == "up" then
    hoveredBtn = math.max(1, (hoveredBtn > 0 and hoveredBtn or 1) - 1)
  end
  if key == "down" then
    hoveredBtn = math.min(#buttons, (hoveredBtn > 0 and hoveredBtn or 1) + 1)
  end
end

-- ─────────────────────────────────────────
-- Draw
-- ─────────────────────────────────────────

local function setColor(c)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * fade)
end

local function drawBackground()
    setColor(C.bg)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Estrelas com tom âmbar/marrom quente em vez de azul-frio
    for _, s in ipairs(stars) do
        love.graphics.setColor(0.72, 0.55, 0.32, s.a * fade)
        love.graphics.circle("fill", s.x, s.y, s.r)
    end

    -- Planeta decorativo — mesmo esquema do landed
    setColor({0.08, 0.04, 0.02, 1})
    love.graphics.circle("fill", G.planetX, G.planetY, G.planetR)
    setColor({0.23, 0.13, 0.05, 1})
    love.graphics.circle("line", G.planetX, G.planetY, G.planetR)

    -- Núcleo interno
    setColor({0.04, 0.02, 0.01, 1})
    love.graphics.circle("fill", G.planetX, G.planetY, G.planetR * 0.76)

    -- Anel
    love.graphics.setColor(0.20, 0.10, 0.04, 0.7 * fade)
    love.graphics.setLineWidth(1)
    love.graphics.push()
        love.graphics.translate(G.planetX, G.planetY)
        love.graphics.rotate(-0.2)
        love.graphics.scale(1, 0.18)
        love.graphics.circle("line", 0, 0, G.planetR * 1.3)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

local function drawTitle()
    setColor(C.textBright)
    love.graphics.setFont(config.bigFont)
    local title = "Você morreu x_x"
    local tw    = config.bigFont:getWidth(title)
    love.graphics.print(title, G.titleX - tw / 2, G.titleY)

    -- Linha decorativa abaixo do título
    local lineW = tw * 0.6
    setColor(C.border)
    love.graphics.rectangle("fill", G.titleX - lineW / 2, G.titleY + config.bigFont:getHeight() + 6, lineW, 1)

end

local function drawButtons()
    for i, btn in ipairs(buttons) do
        local bx       = G.btnStartX
        local by       = G.btnY[i]
        local isHover  = hoveredBtn == i
        local isDanger = btn.danger

        -- Fundo
        local bg = isHover and C.bgBtnHover or C.bgBtn
        setColor(bg)
        love.graphics.rectangle("fill", bx, by, BTN_W, BTN_H, 2)

        -- Borda
        local border = isDanger
            and (isHover and C.borderDanger or C.border)
            or  (isHover and C.borderAccent or C.border)
        setColor(border)
        love.graphics.rectangle("line", bx, by, BTN_W, BTN_H, 2)

        -- Acento esquerdo quando hover
        if isHover then
            local accent = isDanger and C.borderDanger or C.borderAccent
            setColor(accent)
            love.graphics.rectangle("fill", bx, by, 2, BTN_H, 0)
        end

        -- Tecla de atalho
        love.graphics.setFont(config.smallFont)
        local keyColor = isDanger
            and (isHover and C.keyDanger  or C.textMuted)
            or  (isHover and C.keyHover   or C.keyNormal)
        setColor(keyColor)
        love.graphics.print(btn.key, bx + 12, by + BTN_H / 2 - config.smallFont:getHeight() / 2)

        -- Label
        local labelColor = isDanger
            and (isHover and C.textDanger or C.textNormal)
            or  (isHover and C.textActive or C.textNormal)
        setColor(labelColor)
        love.graphics.setFont(config.normalFont)
        love.graphics.print(btn.label, bx + 34, by + BTN_H / 2 - config.normalFont:getHeight() / 2)
    end

    -- Divisor antes do Quit
    setColor(C.border)
    love.graphics.rectangle("fill", G.btnStartX, G.dividerY, BTN_W, 1)
end

local function drawFooter()
    setColor(C.textMuted)
    love.graphics.setFont(config.smallFont)
    local text = "PRESS NUMBER OR CLICK TO SELECT"
    local tw   = config.smallFont:getWidth(text)
    love.graphics.print(text, love.graphics.getWidth() / 2 - tw / 2, G.footerY)
end

function Dead.draw()
    -- O espaço continua visível até o fundo da tela de morte cobri-lo por completo
    if elapsed < BG_FADE_END then
        config.RenderingSystem.draw(nil, config.Camera)
    end

    fade = fadeProgress(BG_FADE_START, BG_FADE_END)
    drawBackground()

    fade = fadeProgress(UI_FADE_START, UI_FADE_END)
    drawTitle()
    drawButtons()
    drawFooter()
    fade = 1
    love.graphics.setColor(1, 1, 1, 1)
    config.DialogueUI.draw()
    config.SelectUI.draw()
    config.TextInputUI.draw()
end

return Dead
