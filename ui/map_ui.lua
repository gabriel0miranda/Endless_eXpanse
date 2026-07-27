-- ui/system_map_ui.lua
--
-- Mapa do sistema: tela cheia do Playing state. Mostra todo o sistema
-- (estrela, planetas/estações, asteroides, naves, buracos de minhoca)
-- centralizado e escalado para caber na área do mapa, com uma lista de
-- entidades filtrável à direita. Selecionar uma entidade na lista ou
-- clicando no mapa define o alvo no TargetingSystem.
--
-- USO
--
--   function Playing.draw()
--     if config.SystemMapUI.isOpen() then
--       config.SystemMapUI.draw(playerFlagShip)
--     else
--       config.RenderingSystem.draw(playerFlagShip, config.Camera)
--     end
--   end
--
--   -- keypressed/mousepressed/wheelmoved/update: ver playing.lua

local MapUI = {}

-- ─────────────────────────────────────────
-- Estado
-- ─────────────────────────────────────────

local open      = false
local player    = nil
local scroll    = 0
local zoom      = 1
local hoveredRow = nil

-- Tags mostradas no mapa/lista (mesmo conjunto do TargetingSystem)
local MAP_TAGS = { "ship", "landable", "asteroid", "star", "wormhole" }

local FILTER_LABELS = {
  ship     = "Naves",
  landable = "Estações/Planetas",
  asteroid = "Asteroides",
  star     = "Estrelas",
  wormhole = "Buracos de Minhoca",
}

local activeFilters = {}
for _, tag in ipairs(MAP_TAGS) do activeFilters[tag] = true end

-- ─────────────────────────────────────────
-- Cores (mesmo tema marrom/âmbar do projeto)
-- ─────────────────────────────────────────

local C = {
  bg           = {0.06, 0.03, 0.01, 0.97},
  bgDark       = {0.04, 0.02, 0.01, 1},
  bgRow        = {0.08, 0.04, 0.02, 1},
  bgRowHover   = {0.12, 0.06, 0.02, 1},
  bgRowSel     = {0.18, 0.10, 0.03, 1},
  border       = {0.23, 0.13, 0.05, 1},
  borderAccent = {0.75, 0.38, 0.13, 1},
  textNormal   = {0.78, 0.62, 0.42, 1},
  textBright   = {0.92, 0.78, 0.58, 1},
  textMuted    = {0.38, 0.22, 0.10, 1},
  textActive   = {0.88, 0.60, 0.22, 1},

  mapBg        = {0.04, 0.05, 0.10, 0.9},
  mapGrid      = {0.20, 0.16, 0.10, 0.25},

  reticule       = {0.99, 0.8, 0.2, 1},
  reticuleLocked = {0.9, 0.5, 0.1, 1},

  -- Cores por tipo de entidade (mesma paleta do minimapa do HUD)
  star     = {0.91, 0.75, 0.37, 1},
  station  = {0.48, 0.67, 0.87, 1},
  planet   = {0.40, 0.65, 0.40, 1},
  asteroid = {0.60, 0.50, 0.40, 1},
  ship     = {0.35, 0.95, 0.55, 1},
  wormhole = {0.68, 0.40, 0.90, 1},
  player   = {0.55, 0.90, 0.75, 1},
}

-- ─────────────────────────────────────────
-- Layout
-- ─────────────────────────────────────────

local MARGIN     = 16
local HEADER_H   = 40
local LIST_W     = 320
local ROW_H      = 26
local CHIP_H     = 22
local CHIP_GAP   = 6
local CHIP_PAD_X = 8
local FILTERS_H  = 62

local ZOOM_MIN, ZOOM_MAX = 0.25, 6

-- Preenchidos a cada draw(), usados para hit-testing no mousepressed
local mapRect      = { x = 0, y = 0, w = 0, h = 0 }
local listRect      = { x = 0, y = 0, w = 0, h = 0 }
local mapTransform  = { centerWX = 0, centerWY = 0, scale = 1, screenCX = 0, screenCY = 0 }
local mapPoints     = {}   -- { {e, tag, sx, sy, r}, ... } para clique no mapa
local listRows      = {}   -- { {e, tag, y}, ... } para clique na lista
local chipRects     = {}   -- { {tag, x, y, w, h}, ... }
local closeBtnRect  = { x = 0, y = 0, w = 0, h = 0 }

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

local function sc(c) love.graphics.setColor(c[1], c[2], c[3], c[4] or 1) end
local function rect(x, y, w, h, col, mode, r) sc(col); love.graphics.rectangle(mode or "fill", x, y, w, h, r or 2) end

local function pointInRect(px, py, r)
  return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- Resolve a posição de mundo de uma entidade, seja ela baseada em
-- rigidbody (naves/asteroides) ou em x,y puro (landables/estrelas/wormholes).
local function getEntityWorldPos(e)
  if e.rigidbody and e.rigidbody.body and not e.rigidbody.body:isDestroyed() then
    return e.rigidbody.body:getPosition()
  elseif e.x and e.y then
    return e.x, e.y
  end
  return nil, nil
end

-- Cor + rótulo de tipo para uma entidade, considerando subtipos
-- (landable pode ser estação ou planeta).
local function getEntityVisual(e, tag)
  if tag == "landable" then
    if e.type == "station" then
      return C.station, "Estação"
    end
    return C.planet, "Planeta"
  elseif tag == "star" then
    return C.star, "Estrela"
  elseif tag == "asteroid" then
    return C.asteroid, "Asteroide"
  elseif tag == "ship" then
    return C.ship, "Nave"
  elseif tag == "wormhole" then
    return C.wormhole, "Wormhole"
  end
  return C.textNormal, tag
end

local function getEntityName(e, tag, idx)
  if e.name then return e.name end
  return (FILTER_LABELS[tag] or tag) .. " #" .. idx
end

local function formatDistance(d)
  if d < 1000 then
    return math.floor(d) .. " u"
  end
  return string.format("%.1fk u", d / 1000)
end

-- ─────────────────────────────────────────
-- Coleta de entidades
-- ─────────────────────────────────────────

-- Retorna a lista completa (sem filtro) de entidades mapeáveis, com
-- posição de mundo resolvida e distância até o jogador.
local function collectEntities(px, py)
  local list = {}
  for _, tag in ipairs(MAP_TAGS) do
    local idx = 0
    for _, e in ipairs(config.Entities.getByTag(tag)) do
      if e ~= player then
        local wx, wy = getEntityWorldPos(e)
        if wx then
          idx = idx + 1
          local dx, dy = wx - px, wy - py
          table.insert(list, {
            e    = e,
            tag  = tag,
            wx   = wx,
            wy   = wy,
            dist = math.sqrt(dx * dx + dy * dy),
            idx  = idx,
          })
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.dist < b.dist end)
  return list
end

-- ─────────────────────────────────────────
-- API pública — ciclo de vida
-- ─────────────────────────────────────────

function MapUI.open(ship)
  config.Input.pushContext("map")
  open   = true
  player = ship
  scroll = 0
  zoom   = 1
end

function MapUI.close()
  config.Input.popContext("map")
  open = false
end

function MapUI.toggle(ship)
  if open then
    MapUI.close()
  else
    MapUI.open(ship)
  end
end

function MapUI.isOpen() return open end

function MapUI.update(dt)
  -- Reservado para futuras animações (pulso de seleção, etc.)
end

-- ─────────────────────────────────────────
-- Input
-- ─────────────────────────────────────────

function MapUI.keypressed(key)
  if config.Input.state.ui_cancel or key == "escape" or key == "m" then
    MapUI.close()
    if config.Input.consume then config.Input.consume("ui_cancel") end
  end
end

function MapUI.mousepressed(mx, my, button)
  if not open then return end
  if button ~= 1 then return end

  -- Botão fechar
  if pointInRect(mx, my, closeBtnRect) then
    MapUI.close()
    return
  end

  -- Chips de filtro
  for _, chip in ipairs(chipRects) do
    if mx >= chip.x and mx <= chip.x + chip.w and my >= chip.y and my <= chip.y + chip.h then
      if chip.tag == "__all__" then
        for _, tag in ipairs(MAP_TAGS) do activeFilters[tag] = true end
      else
        activeFilters[chip.tag] = not activeFilters[chip.tag]
      end
      return
    end
  end

  -- Linhas da lista
  for _, row in ipairs(listRows) do
    if my >= row.y and my < row.y + ROW_H and mx >= listRect.x and mx <= listRect.x + listRect.w then
      if config.TargetingSystem.isValidTarget(row.e) then
        config.TargetingSystem.current = row.e
        config.TargetingSystem.locked  = false
      end
      return
    end
  end

  -- Pontos no mapa (clique seleciona o mais próximo dentro do raio)
  if pointInRect(mx, my, mapRect) then
    local best, bestD2 = nil, math.huge
    local clickRadius = 12
    for _, p in ipairs(mapPoints) do
      local dx, dy = p.sx - mx, p.sy - my
      local d2 = dx * dx + dy * dy
      local rr = (p.r + clickRadius)
      if d2 < rr * rr and d2 < bestD2 then
        bestD2 = d2
        best = p.e
      end
    end
    if best and config.TargetingSystem.isValidTarget(best) then
      config.TargetingSystem.current = best
      config.TargetingSystem.locked  = false
    end
  end
end

function MapUI.wheelmoved(dx, dy)
  if not open then return end
  local mx, my = love.mouse.getPosition()

  if pointInRect(mx, my, mapRect) then
    zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, zoom * (1 + dy * 0.12)))
  elseif pointInRect(mx, my, listRect) then
    -- O clamp final (maxScroll real) acontece em drawList, aqui só evita valores negativos
    scroll = math.max(0, scroll - dy)
  end
end

-- ─────────────────────────────────────────
-- Desenho: mapa
-- ─────────────────────────────────────────

local function drawMap(entities, filtered, px, py)
  rect(mapRect.x, mapRect.y, mapRect.w, mapRect.h, C.mapBg, "fill", 6)
  rect(mapRect.x, mapRect.y, mapRect.w, mapRect.h, C.border, "line", 6)

  love.graphics.push()
  love.graphics.setScissor(mapRect.x + 2, mapRect.y + 2, mapRect.w - 4, mapRect.h - 4)

  -- Bounding box de TODAS as entidades (não só as filtradas) + jogador,
  -- para que o zoom não "pule" ao ligar/desligar filtros.
  local minX, maxX = px, px
  local minY, maxY = py, py
  for _, d in ipairs(entities) do
    if d.wx < minX then minX = d.wx end
    if d.wx > maxX then maxX = d.wx end
    if d.wy < minY then minY = d.wy end
    if d.wy > maxY then maxY = d.wy end
  end

  local rangeX = math.max(maxX - minX, 200)
  local rangeY = math.max(maxY - minY, 200)
  rangeX = rangeX * 1.2
  rangeY = rangeY * 1.2

  local scale = math.min(mapRect.w / rangeX, mapRect.h / rangeY) * zoom
  local centerWX, centerWY = (minX + maxX) / 2, (minY + maxY) / 2
  local screenCX = mapRect.x + mapRect.w / 2
  local screenCY = mapRect.y + mapRect.h / 2

  mapTransform.centerWX = centerWX
  mapTransform.centerWY = centerWY
  mapTransform.scale    = scale
  mapTransform.screenCX = screenCX
  mapTransform.screenCY = screenCY

  local function toScreen(wx, wy)
    return screenCX + (wx - centerWX) * scale, screenCY + (wy - centerWY) * scale
  end

  -- Grade de fundo, só decorativa
  sc(C.mapGrid)
  local gridStep = 60
  for gx = mapRect.x, mapRect.x + mapRect.w, gridStep do
    love.graphics.line(gx, mapRect.y, gx, mapRect.y + mapRect.h)
  end
  for gy = mapRect.y, mapRect.y + mapRect.h, gridStep do
    love.graphics.line(mapRect.x, gy, mapRect.x + mapRect.w, gy)
  end

  mapPoints = {}

  -- Entidades filtradas
  for _, d in ipairs(filtered) do
    local sx, sy = toScreen(d.wx, d.wy)
    local color = getEntityVisual(d.e, d.tag)
    local radius = d.tag == "star" and 6 or (d.tag == "asteroid" and 2 or 3.5)

    local isCurrent = (config.TargetingSystem.current == d.e)

    sc(color)
    love.graphics.circle("fill", sx, sy, radius)

    if isCurrent then
      local pulse = (math.sin(love.timer.getTime() * 4) + 1) / 2
      local ringColor = config.TargetingSystem.locked and C.reticuleLocked or C.reticule
      sc({ringColor[1], ringColor[2], ringColor[3], 0.6 + pulse * 0.4})
      love.graphics.setLineWidth(1.5)
      love.graphics.circle("line", sx, sy, radius + 5)
      love.graphics.setLineWidth(1)

      love.graphics.setFont(fontSmall)
      sc(C.textBright)
      local label = d.e.name or (FILTER_LABELS[d.tag] or d.tag)
      love.graphics.print(label, sx + radius + 8, sy - fontSmall:getHeight() / 2)
    end

    table.insert(mapPoints, { e = d.e, tag = d.tag, sx = sx, sy = sy, r = radius })
  end

  -- Jogador sempre visível, independente dos filtros
  local psx, psy = toScreen(px, py)
  sc(C.player)
  love.graphics.circle("fill", psx, psy, 4)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.circle("line", psx, psy, 6)

  love.graphics.setScissor()
  love.graphics.pop()

  -- Escala aproximada, no canto inferior do mapa
  love.graphics.setFont(fontSmall)
  sc(C.textMuted)
  local scaleUnits = math.floor(100 / scale)
  love.graphics.print("~" .. scaleUnits .. " u / 100px    (scroll para zoom)",
    mapRect.x + 8, mapRect.y + mapRect.h - 16)

  love.graphics.setColor(1, 1, 1, 1)
end

-- ─────────────────────────────────────────
-- Desenho: filtros + lista
-- ─────────────────────────────────────────

local function drawFilters(x, y, w)
  chipRects = {}
  love.graphics.setFont(fontSmall)

  local cx, cy = x, y
  local rowH = CHIP_H + CHIP_GAP

  local function drawChip(label, tag, active)
    local tw = fontSmall:getWidth(label) + CHIP_PAD_X * 2
    if cx + tw > x + w then
      cx = x
      cy = cy + rowH
    end
    local bg = active and C.bgRowSel or C.bgRow
    local border = active and C.borderAccent or C.border
    rect(cx, cy, tw, CHIP_H, bg, "fill", 4)
    rect(cx, cy, tw, CHIP_H, border, "line", 4)
    sc(active and C.textActive or C.textMuted)
    love.graphics.print(label, cx + CHIP_PAD_X, cy + math.floor(CHIP_H / 2 - fontSmall:getHeight() / 2))
    table.insert(chipRects, { tag = tag, x = cx, y = cy, w = tw, h = CHIP_H })
    cx = cx + tw + CHIP_GAP
  end

  local allActive = true
  for _, tag in ipairs(MAP_TAGS) do
    if not activeFilters[tag] then allActive = false end
  end
  drawChip("Todos", "__all__", allActive)
  for _, tag in ipairs(MAP_TAGS) do
    drawChip(FILTER_LABELS[tag], tag, activeFilters[tag])
  end

  return cy + rowH -- y onde os filtros terminam
end

local function drawList(filtered, listX, listY, listW, listH)
  local mx, my = love.mouse.getPosition()
  listRows = {}

  rect(listX, listY, listW, 20, C.bgDark)
  sc(C.textMuted)
  love.graphics.setFont(fontSmall)
  love.graphics.print(#filtered .. " entidade(s)", listX + 6, listY + 4)
  local top = listY + 20

  local visibleH = listH - 20
  local maxVisible = math.max(1, math.floor(visibleH / ROW_H))
  local maxScroll = math.max(0, #filtered - maxVisible)
  scroll = math.max(0, math.min(maxScroll, scroll))

  love.graphics.setScissor(listX, top, listW, visibleH)
  for i = 1, math.min(maxVisible + 1, #filtered) do
    local idx = i + math.floor(scroll)
    local d = filtered[idx]
    if not d then break end
    local ry = top + (i - 1) * ROW_H

    local hov = mx >= listX and mx <= listX + listW and my >= ry and my < ry + ROW_H
    local isCurrent = (config.TargetingSystem.current == d.e)
    local bg = isCurrent and C.bgRowSel or (hov and C.bgRowHover or C.bgRow)
    rect(listX, ry, listW, ROW_H - 2, bg)

    local color = getEntityVisual(d.e, d.tag)
    sc(color)
    love.graphics.circle("fill", listX + 10, ry + ROW_H / 2 - 1, 4)

    love.graphics.setFont(fontLabel)
    sc(isCurrent and C.textActive or C.textNormal)
    local name = getEntityName(d.e, d.tag, d.idx)
    love.graphics.print(name, listX + 22, ry + 4)

    love.graphics.setFont(fontSmall)
    sc(C.textMuted)
    local distStr = formatDistance(d.dist)
    local tw = fontSmall:getWidth(distStr)
    love.graphics.print(distStr, listX + listW - tw - 8, ry + 6)

    table.insert(listRows, { e = d.e, tag = d.tag, y = ry })
  end
  love.graphics.setScissor()

  -- Scrollbar
  if #filtered > maxVisible then
    local trackH = visibleH
    local thumbH = math.max(20, trackH * (maxVisible / #filtered))
    local thumbY = top + (scroll / maxScroll) * (trackH - thumbH)
    rect(listX + listW - 4, top, 4, trackH, C.bgDark)
    rect(listX + listW - 4, thumbY, 4, thumbH, C.border)
  end

  if #filtered == 0 then
    sc(C.textMuted)
    love.graphics.setFont(fontLabel)
    love.graphics.print("Nenhuma entidade com esse filtro", listX + 8, top + 8)
  end
end

-- ─────────────────────────────────────────
-- Desenho principal
-- ─────────────────────────────────────────

function MapUI.draw(ship)
  if not open then return end
  initFonts()
  player = ship or player
  if not player or not player.rigidbody or not player.rigidbody.body then return end

  local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
  local px, py = player.rigidbody.body:getPosition()

  -- Fundo escurecendo tudo atrás
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, sw, sh)

  -- Painel base cobrindo a tela toda
  rect(0, 0, sw, sh, C.bg)

  -- ── Titlebar ──
  rect(0, 0, sw, HEADER_H, C.bgDark)
  love.graphics.setFont(fontTitle)
  sc(C.textActive)
  love.graphics.print("MAPA DO SISTEMA", MARGIN, 10)

  closeBtnRect = { x = sw - 36, y = 8, w = 24, h = 24 }
  rect(closeBtnRect.x, closeBtnRect.y, closeBtnRect.w, closeBtnRect.h, C.bgRow)
  rect(closeBtnRect.x, closeBtnRect.y, closeBtnRect.w, closeBtnRect.h, C.border, "line")
  sc(C.textMuted)
  love.graphics.setFont(fontLabel)
  love.graphics.printf("x", closeBtnRect.x, closeBtnRect.y + 5, closeBtnRect.w, "center")

  sc(C.textMuted)
  love.graphics.setFont(fontSmall)
  love.graphics.print("ESC/M para fechar", sw - 160, 14)

  -- ── Layout ──
  local top = HEADER_H + MARGIN
  local listX = sw - LIST_W - MARGIN
  local mapW  = listX - MARGIN * 2
  local contentH = sh - top - MARGIN

  mapRect  = { x = MARGIN, y = top, w = mapW, h = contentH }
  listRect = { x = listX, y = top, w = LIST_W, h = contentH }

  -- ── Coleta e filtro de entidades ──
  local entities = collectEntities(px, py)
  local filtered = {}
  for _, d in ipairs(entities) do
    if activeFilters[d.tag] then table.insert(filtered, d) end
  end

  drawMap(entities, filtered, px, py)

  -- ── Painel de lista ──
  rect(listRect.x, listRect.y, listRect.w, listRect.h, C.bgDark, "fill", 4)
  rect(listRect.x, listRect.y, listRect.w, listRect.h, C.border, "line", 4)

  local filtersBottom = drawFilters(listRect.x + 8, listRect.y + 8, listRect.w - 16)
  rect(listRect.x, filtersBottom + 4, listRect.w, 1, C.border)

  local listInnerY = filtersBottom + 8
  local listInnerH = listRect.y + listRect.h - listInnerY - 8
  drawList(filtered, listRect.x + 4, listInnerY, listRect.w - 8, listInnerH)

  love.graphics.setColor(1, 1, 1, 1)
end

return MapUI
