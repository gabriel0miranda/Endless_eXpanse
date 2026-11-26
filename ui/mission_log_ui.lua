-- ui/mission_log_ui.lua
--
-- Diário de missões: lista as missões ativas à esquerda e mostra a
-- selecionada à direita (objetivo, prazo, recompensa e contratante). Da
-- missão dá para abrir o mapa da galáxia no sistema-alvo ou desistir dela.
-- O rodapé mostra a reputação com as facções.
--
-- Abre em voo e pousado (action ui_missions, tecla J por padrão), por cima
-- de diálogos. O mapa aberto daqui fica por cima do diário; fechar o mapa
-- volta ao diário.

local MissionLogUI = {}

local open     = false
local selected = 1
local armed    = false   -- true: o próximo clique em Desistir confirma
local msg      = nil     -- mensagem do rodapé (resultado da última ação)

local C = {
  bg          = {0.06, 0.03, 0.01, 0.97},
  bgDark      = {0.04, 0.02, 0.01, 1},
  bgRow       = {0.08, 0.04, 0.02, 1},
  bgRowHover  = {0.12, 0.06, 0.02, 1},
  bgRowSel    = {0.16, 0.08, 0.02, 1},
  border      = {0.23, 0.13, 0.05, 1},
  borderAccent= {0.75, 0.38, 0.13, 1},
  textNormal  = {0.78, 0.62, 0.42, 1},
  textBright  = {0.92, 0.78, 0.58, 1},
  textMuted   = {0.38, 0.22, 0.10, 1},
  textActive  = {0.88, 0.60, 0.22, 1},
  textDanger  = {0.80, 0.30, 0.20, 1},
  repPos      = {0.35, 0.72, 0.35, 1},
  repNeg      = {0.80, 0.35, 0.25, 1},
}

local W, H     = 760, 460
local HEADER_H = 30
local FOOTER_H = 44
local LIST_W   = 280
local ROW_H    = 40
local PAD      = 12

local PX, PY = 0, 0
local rects = {}   -- { {x, y, w, h, action}, ... } montados no draw

local function sc(c) love.graphics.setColor(c[1], c[2], c[3], c[4] or 1) end
local function rect(x, y, w, h, col, mode) sc(col); love.graphics.rectangle(mode or "fill", x, y, w, h, 2) end

local function missions() return config.Missions.active() end

local function current()
  return missions()[selected]
end

local function clampSelection()
  local n = #missions()
  if selected > n then selected = n end
  if selected < 1 then selected = 1 end
end

function MissionLogUI.open()
  if open then return end
  open, armed, msg = true, false, nil
  clampSelection()
  config.Input.pushContext("missionlog")
end

function MissionLogUI.close()
  if not open then return end
  open = false
  config.Input.popContext("missionlog")
end

function MissionLogUI.toggle()
  if open then MissionLogUI.close() else MissionLogUI.open() end
end

function MissionLogUI.isOpen() return open end

function MissionLogUI.update(dt) end

local function select(i)
  selected, armed = i, false
  clampSelection()
end

local function showOnMap()
  local m = current()
  local target = m and config.Missions.targetSystem(m)
  if not target then return end
  config.GalaxyMapUI.open({ canTarget = config.GameState.current == "playing" })
  config.GalaxyMapUI.select(target)
end

local function abandon()
  local m = current()
  if not m or m.story then return end
  if not armed then
    armed = true
    return
  end
  local result = config.Missions.abandon(m.id)
  armed = false
  msg = result and result.text or nil
  clampSelection()
end

function MissionLogUI.keypressed(key)
  if not open then return end
  if key == "escape" or config.Input.state.ui_cancel then
    MissionLogUI.close()
  elseif key == "up" then
    select(selected - 1)
  elseif key == "down" then
    select(selected + 1)
  end
end

function MissionLogUI.mousepressed(mx, my, button)
  if not open or button ~= 1 then return end
  for _, r in ipairs(rects) do
    if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
      r.action()
      return
    end
  end
end

function MissionLogUI.wheelmoved(dx, dy) end

-- ─────────────────────────────────────────
-- Desenho
-- ─────────────────────────────────────────

local function addRect(x, y, w, h, action)
  rects[#rects + 1] = { x = x, y = y, w = w, h = h, action = action }
end

local function hovered(x, y, w, h)
  local mx, my = love.mouse.getPosition()
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function button(x, y, w, h, label, color, action)
  local hov = hovered(x, y, w, h)
  rect(x, y, w, h, hov and C.bgRowHover or C.bgRow)
  rect(x, y, w, h, hov and color or C.border, "line")
  sc(hov and C.textBright or color)
  love.graphics.setFont(config.smallFont)
  love.graphics.printf(label, x, y + h / 2 - config.smallFont:getHeight() / 2, w, "center")
  addRect(x, y, w, h, action)
end

local function drawList(x, y, w, h)
  rect(x, y, w, h, C.bgDark)
  rect(x, y, w, h, C.border, "line")
  love.graphics.setFont(config.smallFont)
  local list = missions()
  if #list == 0 then
    sc(C.textMuted)
    love.graphics.printf("Nenhuma missão ativa. Procure trabalho nos bares.", x + 10, y + 12, w - 20)
    return
  end
  local maxRows = math.floor(h / ROW_H)
  for i = 1, math.min(#list, maxRows) do
    local m = list[i]
    local ry = y + (i - 1) * ROW_H
    local isSel = i == selected
    rect(x + 1, ry + 1, w - 2, ROW_H - 2, isSel and C.bgRowSel or (hovered(x, ry, w, ROW_H) and C.bgRowHover or C.bgRow))
    if isSel then rect(x + 1, ry + 1, 2, ROW_H - 2, C.borderAccent) end
    sc(isSel and C.textActive or C.textNormal)
    love.graphics.printf(m.title, x + 10, ry + 5, w - 20)
    sc(C.textMuted)
    local sub = m.deadline and ("Prazo: " .. config.Calendar.format(m.deadline)) or "Sem prazo"
    love.graphics.print(sub, x + 10, ry + 22)
    addRect(x, ry, w, ROW_H, function() select(i) end)
  end
end

local function drawDetails(x, y, w, h)
  rect(x, y, w, h, C.bgDark)
  rect(x, y, w, h, C.border, "line")
  local m = current()
  if not m then return end

  local px, py, lw = x + PAD, y + PAD, w - PAD * 2
  local function line(text, font, color, gap)
    love.graphics.setFont(font)
    sc(color)
    love.graphics.printf(text, px, py, lw)
    local _, wrapped = font:getWrap(text, lw)
    py = py + #wrapped * font:getHeight() + (gap or 4)
  end

  line(m.title, config.normalFont, C.textActive, 10)
  line(m.text or "", config.smallFont, C.textNormal, 12)
  line("Objetivo", config.smallFont, C.textMuted, 2)
  line(config.Missions.objectiveText(m), config.smallFont, C.textBright, 10)
  line("Prazo", config.smallFont, C.textMuted, 2)
  line(m.deadline and config.Calendar.format(m.deadline) or "Sem prazo", config.smallFont, C.textBright, 10)
  if m.reward and m.reward > 0 then
    line("Recompensa", config.smallFont, C.textMuted, 2)
    line(m.reward .. " cr", config.smallFont, C.textBright, 10)
  end
  if m.faction then
    line("Contratante", config.smallFont, C.textMuted, 2)
    line(m.faction, config.smallFont, C.textBright, 10)
  end

  -- Botões
  local by = y + h - 36
  local bx = x + w - PAD
  if not m.story then
    bx = bx - 170
    button(bx, by, 170, 26, armed and "Confirmar desistência" or "Desistir", C.textDanger, abandon)
  end
  if config.Missions.targetSystem(m) then
    bx = bx - 120
    button(bx, by, 110, 26, "Ver no mapa", C.borderAccent, showOnMap)
  end
end

local function drawFooter(x, y, w)
  love.graphics.setFont(config.smallFont)
  if msg then
    sc(C.textActive)
    love.graphics.printf(msg, x, y + 4, w)
    return
  end
  local reps = config.WorldState.reputations()
  local factions = {}
  for f in pairs(reps) do factions[#factions + 1] = f end
  table.sort(factions)
  sc(C.textMuted)
  love.graphics.print("Reputação:", x, y + 4)
  local cx = x + config.smallFont:getWidth("Reputação:") + 8
  if #factions == 0 then
    love.graphics.print("ninguém conhece você ainda.", cx, y + 4)
    return
  end
  for _, f in ipairs(factions) do
    local v = reps[f]
    local text = string.format("%s %+d", f, v)
    sc(v >= 0 and C.repPos or C.repNeg)
    love.graphics.print(text, cx, y + 4)
    cx = cx + config.smallFont:getWidth(text) + 16
  end
end

function MissionLogUI.draw()
  if not open then return end
  rects = {}
  clampSelection()
  local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
  PX, PY = math.floor(sw / 2 - W / 2), math.floor(sh / 2 - H / 2)

  rect(PX, PY, W, H, C.bg)
  rect(PX, PY, W, H, C.border, "line")
  rect(PX, PY, W, HEADER_H, C.bgDark)
  love.graphics.setFont(config.normalFont)
  sc(C.textActive)
  love.graphics.print("Missões", PX + PAD, PY + 4)

  -- Fechar
  local cx, cy = PX + W - 26, PY + 5
  rect(cx, cy, 20, 20, C.bgRow)
  rect(cx, cy, 20, 20, C.border, "line")
  sc(C.textNormal)
  love.graphics.setFont(config.smallFont)
  love.graphics.printf("x", cx, cy + 3, 20, "center")
  addRect(cx, cy, 20, 20, MissionLogUI.close)

  local top = PY + HEADER_H + PAD
  local bodyH = H - HEADER_H - FOOTER_H - PAD
  drawList(PX + PAD, top, LIST_W, bodyH)
  drawDetails(PX + PAD * 2 + LIST_W, top, W - LIST_W - PAD * 3, bodyH)
  drawFooter(PX + PAD, PY + H - FOOTER_H + 10, W - PAD * 2)
end

return MissionLogUI
