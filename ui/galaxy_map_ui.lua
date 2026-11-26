-- ui/galaxy_map_ui.lua
--
-- Mapa da galáxia: tela cheia com os sistemas conhecidos sobre a espiral da
-- galáxia (data/galaxy.lua), os buracos de minhoca conhecidos e, à direita,
-- os dados do sistema selecionado. Selecionar um sistema traça a rota até
-- ele (systems/navigation.lua). Em voo, o buraco de minhoca do próximo
-- salto vira o alvo da nave.
--
-- Abre em voo, pousado e por cima de diálogos (action ui_galaxy_map, tecla
-- N por padrão). O estado que abre o mapa repassa a ele teclado, mouse e
-- roda enquanto ele estiver aberto, e o desenha por cima de tudo.

local GalaxyMapUI = {}

-- ─────────────────────────────────────────
-- Estado
-- ─────────────────────────────────────────

local open      = false
local canTarget = false   -- em voo: o próximo salto vira o alvo
local zoom      = 1
local panX, panY = 0, 0   -- centro da tela, em coordenadas do mapa
local selected  = nil     -- id do sistema selecionado
local route     = nil     -- ids do sistema atual até o selecionado
local targeted  = nil     -- nome do buraco de minhoca marcado como alvo
local drag      = nil     -- { x, y, moved, onNode } do arraste em curso
local DEFAULT_ZOOM = 3
local CLICK_SLOP   = 4       -- pixels que um clique pode andar sem virar arraste

local armPoints = nil     -- fundo: pontos dos braços, gerados uma vez

-- ─────────────────────────────────────────
-- Cores (tema marrom/âmbar do projeto)
-- ─────────────────────────────────────────

local C = {
  bg           = {0.06, 0.03, 0.01, 0.97},
  bgDark       = {0.04, 0.02, 0.01, 1},
  bgRow        = {0.08, 0.04, 0.02, 1},
  border       = {0.23, 0.13, 0.05, 1},
  textNormal   = {0.78, 0.62, 0.42, 1},
  textBright   = {0.92, 0.78, 0.58, 1},
  textMuted    = {0.38, 0.22, 0.10, 1},
  textActive   = {0.88, 0.60, 0.22, 1},

  mapBg        = {0.02, 0.02, 0.05, 1},
  arm          = {0.55, 0.45, 0.70},
  core         = {1.00, 0.85, 0.55},

  visited      = {0.88, 0.60, 0.22, 1},
  neighbor     = {0.55, 0.42, 0.28, 1},
  revealed     = {0.45, 0.80, 0.90, 1},
  link         = {0.45, 0.30, 0.15, 1},
  route        = {0.99, 0.80, 0.20, 1},
  current      = {0.55, 0.90, 0.75, 1},
  mission      = {0.95, 0.45, 0.30, 1},
}

local KNOWLEDGE_LABELS = {
  visited  = "Visitado",
  neighbor = "Não visitado",
  revealed = "Marcado no mapa",
}

-- ─────────────────────────────────────────
-- Layout
-- ─────────────────────────────────────────

local MARGIN   = 16
local HEADER_H = 40
local PANEL_W  = 300
local ZOOM_MIN, ZOOM_MAX = 0.5, 8

local mapRect      = { x = 0, y = 0, w = 0, h = 0 }
local closeBtnRect = { x = 0, y = 0, w = 0, h = 0 }
local nodePoints   = {}   -- { {id, sx, sy}, ... } para o clique

local fontTitle, fontLabel, fontSmall

local function initFonts()
  if fontTitle then return end
  fontTitle = love.graphics.newFont(16)
  fontLabel = love.graphics.newFont(12)
  fontSmall = love.graphics.newFont(10)
end

-- ─────────────────────────────────────────
-- Utilitários
-- ─────────────────────────────────────────

local function sc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1) end
local function rect(x, y, w, h, col, mode, r) sc(col); love.graphics.rectangle(mode or "fill", x, y, w, h, r or 2) end

local function pointInRect(px, py, r)
  return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- Pixels por unidade do mapa: a galáxia inteira cabe na tela com zoom 1
local function scale()
  local g = config.GalaxyData
  return math.min(mapRect.w, mapRect.h) / (g.radius * 2.2) * zoom
end

local function toScreen(mx, my)
  local s = scale()
  return mapRect.x + mapRect.w / 2 + (mx - panX) * s,
         mapRect.y + mapRect.h / 2 + (my - panY) * s
end

local function toMap(sx, sy)
  local s = scale()
  return panX + (sx - mapRect.x - mapRect.w / 2) / s,
         panY + (sy - mapRect.y - mapRect.h / 2) / s
end

-- Pontos dos braços da espiral, com espalhamento fixo (mesma semente)
local function buildArms()
  local g = config.GalaxyData
  local rng = love.math.newRandomGenerator(1)
  armPoints = {}
  for arm = 0, g.arms - 1 do
    local phase = math.rad(g.phase) + arm * 2 * math.pi / g.arms
    for _ = 1, 700 do
      local r = g.core * 0.6 + (g.radius - g.core * 0.6) * rng:random() ^ 0.8
      local angle = phase - g.winding * math.log(g.radius / r)
      local spread = 10 + r * 0.035
      local x = r * math.cos(angle) + rng:randomNormal(spread)
      local y = r * math.sin(angle) + rng:randomNormal(spread)
      armPoints[#armPoints + 1] = { x, y, 0.15 + rng:random() * 0.3 }
    end
  end
end

-- Marca o buraco de minhoca do próximo salto como alvo da nave
local function targetNextJump()
  targeted = nil
  if not (canTarget and route and #route > 1) then return end
  local name = config.Navigation.wormholeTo(route[1], route[2])
  -- Buracos de minhoca são entidades "landable" com o campo `wormhole`
  for _, w in ipairs(config.Entities.getByTag("landable")) do
    if w.wormhole and w.name == name and config.TargetingSystem.isValidTarget(w) then
      config.TargetingSystem.current = w
      config.TargetingSystem.locked  = false
      targeted = name
    end
  end
end

local function selectSystem(id)
  selected = id
  route = id and config.Navigation.route(config.WorldState.currentSystemId(), id) or nil
  targetNextJump()
end

-- ─────────────────────────────────────────
-- API pública — ciclo de vida
-- ─────────────────────────────────────────

-- opts.canTarget: em voo, o próximo salto da rota vira o alvo da nave
function GalaxyMapUI.open(opts)
  config.Input.pushContext("galaxymap")
  open      = true
  canTarget = opts and opts.canTarget or false
  zoom      = DEFAULT_ZOOM
  drag      = nil
  -- Centraliza no sistema selecionado ou, sem seleção, onde o jogador está
  local focus = config.Systems[selected or config.WorldState.currentSystemId()]
  panX, panY = focus and focus.mapX or 0, focus and focus.mapY or 0
  selectSystem(selected)
end

function GalaxyMapUI.close()
  config.Input.popContext("galaxymap")
  open = false
  drag = nil
end

function GalaxyMapUI.toggle(opts)
  if open then GalaxyMapUI.close() else GalaxyMapUI.open(opts) end
end

function GalaxyMapUI.isOpen() return open end

-- Seleciona um sistema, traça a rota até ele e centraliza o mapa nele
function GalaxyMapUI.select(id)
  selectSystem(id)
  local sys = id and config.Systems[id]
  if sys then panX, panY = sys.mapX or 0, sys.mapY or 0 end
end

-- Arrastar com o botão esquerdo move o mapa. Um clique no vazio (sem
-- arraste) limpa a seleção quando o botão é solto.
function GalaxyMapUI.update(dt)
  if not open or not drag then return end
  local mx, my = love.mouse.getPosition()
  if love.mouse.isDown(1) then
    if (mx - drag.startX) ^ 2 + (my - drag.startY) ^ 2 > CLICK_SLOP ^ 2 then drag.moved = true end
    local s = scale()
    panX = panX - (mx - drag.x) / s
    panY = panY - (my - drag.y) / s
    drag.x, drag.y = mx, my
  else
    if not drag.moved and not drag.onNode then selectSystem(nil) end
    drag = nil
  end
end

-- ─────────────────────────────────────────
-- Input
-- ─────────────────────────────────────────

-- A tecla do mapa (ui_galaxy_map) é tratada pelo estado; aqui só o Esc
function GalaxyMapUI.keypressed(key)
  if key == "escape" then
    GalaxyMapUI.close()
  end
end

function GalaxyMapUI.mousepressed(mx, my, button)
  if not open or button ~= 1 then return end

  if pointInRect(mx, my, closeBtnRect) then
    GalaxyMapUI.close()
    return
  end

  if pointInRect(mx, my, mapRect) then
    local best, bestD2 = nil, 14 * 14
    for _, p in ipairs(nodePoints) do
      local d2 = (p.sx - mx) ^ 2 + (p.sy - my) ^ 2
      if d2 < bestD2 then best, bestD2 = p.id, d2 end
    end
    if best then selectSystem(best) end
    drag = { x = mx, y = my, startX = mx, startY = my, moved = false, onNode = best ~= nil }
  end
end

function GalaxyMapUI.wheelmoved(dx, dy)
  if not open then return end
  local mx, my = love.mouse.getPosition()
  if not pointInRect(mx, my, mapRect) then return end
  -- Zoom em volta do cursor: o ponto sob o mouse fica parado
  local beforeX, beforeY = toMap(mx, my)
  zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, zoom * (1 + dy * 0.15)))
  local afterX, afterY = toMap(mx, my)
  panX, panY = panX + beforeX - afterX, panY + beforeY - afterY
end

-- ─────────────────────────────────────────
-- Desenho: mapa
-- ─────────────────────────────────────────

local function drawBackground()
  local g = config.GalaxyData
  if not armPoints then buildArms() end
  local s = scale()

  -- Núcleo: brilho em camadas
  local cx, cy = toScreen(0, 0)
  for i = 6, 1, -1 do
    sc(C.core, 0.05)
    love.graphics.circle("fill", cx, cy, g.core * s * i / 4)
  end

  local size = math.max(1, 1.6 * math.sqrt(zoom))
  for _, p in ipairs(armPoints) do
    local x, y = toScreen(p[1], p[2])
    if pointInRect(x, y, mapRect) then
      sc(C.arm, p[3])
      love.graphics.circle("fill", x, y, size)
    end
  end
end

local function drawLinks()
  local onRoute = {}
  for i = 1, #(route or {}) - 1 do
    onRoute[math.min(route[i], route[i + 1]) .. "-" .. math.max(route[i], route[i + 1])] = true
  end
  for _, link in ipairs(config.Navigation.knownLinks()) do
    local a, b = config.Systems[link.from], config.Systems[link.to]
    local ax, ay = toScreen(a.mapX or 0, a.mapY or 0)
    local bx, by = toScreen(b.mapX or 0, b.mapY or 0)
    local key = math.min(link.from, link.to) .. "-" .. math.max(link.from, link.to)
    if onRoute[key] then
      sc(C.route)
      love.graphics.setLineWidth(3)
    else
      sc(C.link)
      love.graphics.setLineWidth(1.5)
    end
    love.graphics.line(ax, ay, bx, by)
  end
  love.graphics.setLineWidth(1)
end

local function drawNodes()
  nodePoints = {}
  local currentId = config.WorldState.currentSystemId()
  local missionTargets = config.Missions.targetSystems()
  love.graphics.setFont(fontLabel)

  for id, sys in pairs(config.Systems) do
    local knowledge = config.Navigation.knowledge(id)
    if knowledge then
      local sx, sy = toScreen(sys.mapX or 0, sys.mapY or 0)
      local color = C[knowledge]

      if knowledge == "revealed" then
        -- Losango: sistema marcado no mapa, sem visita
        sc(color)
        love.graphics.polygon("line", sx, sy - 7, sx + 7, sy, sx, sy + 7, sx - 7, sy)
        love.graphics.circle("fill", sx, sy, 2)
      elseif knowledge == "neighbor" then
        sc(C.mapBg)
        love.graphics.circle("fill", sx, sy, 5)
        sc(color)
        love.graphics.circle("line", sx, sy, 5)
      else
        sc(color)
        love.graphics.circle("fill", sx, sy, 6)
      end

      if id == currentId then
        local pulse = (math.sin(love.timer.getTime() * 3) + 1) / 2
        sc(C.current, 0.5 + pulse * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", sx, sy, 11)
        love.graphics.setLineWidth(1)
      end
      if id == selected then
        sc(C.route)
        love.graphics.rectangle("line", sx - 12, sy - 12, 24, 24, 3)
      end
      -- Bandeira: sistema-alvo de uma missão ativa
      if missionTargets[id] then
        sc(C.mission)
        love.graphics.line(sx - 8, sy - 8, sx - 8, sy - 22)
        love.graphics.polygon("fill", sx - 8, sy - 22, sx + 2, sy - 18, sx - 8, sy - 14)
      end

      sc(knowledge == "neighbor" and C.textNormal or C.textBright)
      love.graphics.print(sys.name or ("#" .. id), sx + 12, sy - 14)

      nodePoints[#nodePoints + 1] = { id = id, sx = sx, sy = sy }
    end
  end
end

local function drawMap()
  rect(mapRect.x, mapRect.y, mapRect.w, mapRect.h, C.mapBg, "fill", 6)
  love.graphics.setScissor(mapRect.x + 2, mapRect.y + 2, mapRect.w - 4, mapRect.h - 4)
  drawBackground()
  drawLinks()
  drawNodes()
  love.graphics.setScissor()
  rect(mapRect.x, mapRect.y, mapRect.w, mapRect.h, C.border, "line", 6)

  love.graphics.setFont(fontSmall)
  sc(C.textMuted)
  love.graphics.print("clique para selecionar · arraste para mover · roda para zoom",
    mapRect.x + 8, mapRect.y + mapRect.h - 16)
end

-- ─────────────────────────────────────────
-- Desenho: painel do sistema selecionado
-- ─────────────────────────────────────────

local function drawPanel(x, y, w, h)
  rect(x, y, w, h, C.bgDark, "fill", 4)
  rect(x, y, w, h, C.border, "line", 4)

  local px, py = x + 12, y + 12
  local lineW = w - 24
  local function line(text, font, color, gap)
    love.graphics.setFont(font)
    sc(color)
    love.graphics.printf(text, px, py, lineW)
    local _, wrapped = font:getWrap(text, lineW)
    py = py + #wrapped * font:getHeight() + (gap or 4)
  end

  local sys = selected and config.Systems[selected]
  if not sys then
    line("Clique num sistema para ver os dados e traçar a rota até ele.", fontLabel, C.textMuted)
    return
  end

  local knowledge = config.Navigation.knowledge(selected)
  local currentId = config.WorldState.currentSystemId()

  line(sys.name or ("#" .. selected), fontTitle, C.textActive, 8)
  line(KNOWLEDGE_LABELS[knowledge] or "", fontSmall, C.textMuted, 12)

  if knowledge == "visited" then
    local names = {}
    for _, key in ipairs(sys.landables or {}) do
      local data = config.Landables[key]
      names[#names + 1] = data and data.name or key
    end
    line("Locais", fontSmall, C.textMuted, 2)
    line(#names > 0 and table.concat(names, ", ") or "nenhum", fontLabel, C.textNormal, 10)

    local links = {}
    for _, to in ipairs(config.Navigation.neighbors(selected)) do
      links[#links + 1] = config.Systems[to].name or ("#" .. to)
    end
    line("Buracos de minhoca para", fontSmall, C.textMuted, 2)
    line(#links > 0 and table.concat(links, ", ") or "nenhum", fontLabel, C.textNormal, 12)
  end

  local missions = {}
  for _, m in ipairs(config.Missions.active()) do
    if config.Missions.targetSystem(m) == selected then missions[#missions + 1] = m.title end
  end
  if #missions > 0 then
    line("Missões", fontSmall, C.textMuted, 2)
    line(table.concat(missions, "\n"), fontLabel, C.mission, 12)
  end

  line("Rota", fontSmall, C.textMuted, 2)
  if selected == currentId then
    line("Você está aqui.", fontLabel, C.current)
  elseif not route then
    line("Rota desconhecida.", fontLabel, C.textNormal)
  else
    local names = {}
    for _, id in ipairs(route) do names[#names + 1] = config.Systems[id].name or ("#" .. id) end
    line(string.format("%d salto(s): %s", #route - 1, table.concat(names, " > ")), fontLabel, C.route, 8)
    local jump = config.Navigation.wormholeTo(route[1], route[2])
    line("Próximo salto: " .. (jump or "?"), fontLabel, C.textNormal)
    if targeted then
      line("Marcado como alvo da nave.", fontSmall, C.textMuted)
    end
  end
end

-- ─────────────────────────────────────────
-- Desenho principal
-- ─────────────────────────────────────────

function GalaxyMapUI.draw()
  if not open then return end
  initFonts()

  local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
  rect(0, 0, sw, sh, C.bg, "fill", 0)

  -- ── Barra de título ──
  rect(0, 0, sw, HEADER_H, C.bgDark, "fill", 0)
  love.graphics.setFont(fontTitle)
  sc(C.textActive)
  love.graphics.print("MAPA DA GALÁXIA", MARGIN, 10)

  closeBtnRect = { x = sw - 36, y = 8, w = 24, h = 24 }
  rect(closeBtnRect.x, closeBtnRect.y, closeBtnRect.w, closeBtnRect.h, C.bgRow)
  rect(closeBtnRect.x, closeBtnRect.y, closeBtnRect.w, closeBtnRect.h, C.border, "line")
  sc(C.textMuted)
  love.graphics.setFont(fontLabel)
  love.graphics.printf("x", closeBtnRect.x, closeBtnRect.y + 5, closeBtnRect.w, "center")

  local key = (config.Input.keyFor("ui_galaxy_map") or "?"):upper()
  local hint = "ESC/" .. key .. " para fechar"
  love.graphics.setFont(fontSmall)
  love.graphics.print(hint, closeBtnRect.x - 12 - fontSmall:getWidth(hint), 14)

  -- ── Layout ──
  local top = HEADER_H + MARGIN
  local panelX = sw - PANEL_W - MARGIN
  local contentH = sh - top - MARGIN
  mapRect = { x = MARGIN, y = top, w = panelX - MARGIN * 2, h = contentH }

  drawMap()
  drawPanel(panelX, top, PANEL_W, contentH)

  love.graphics.setColor(1, 1, 1, 1)
end

return GalaxyMapUI
