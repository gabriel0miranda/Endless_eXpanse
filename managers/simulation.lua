-- Relógio da simulação em passo fixo.
--
-- O mundo (sistemas de jogo + Box2D) sempre avança em passos de STEP segundos,
-- independente do FPS. O tempo real de cada frame entra num acumulador e vira
-- zero, um ou vários passos. Sem isso, um frame lento vira um único passo
-- longo, e o Box2D corta a velocidade das naves rápidas (máximo de 2 m, ou
-- 60 px, de deslocamento por passo).
local Simulation = {}

Simulation.STEP = 1 / 60

-- Frames mais longos que isso (engasgos, janela arrastada, breakpoint) deixam
-- o jogo mais lento em vez de rodar dezenas de passos de uma vez.
local MAX_FRAME_TIME = 0.1

-- Tolerância para o jitter do vsync: um frame de ~16,6 ms roda sempre um passo,
-- em vez de alternar entre zero e dois.
local SNAP = 0.002

local accumulator = 0

-- Tempo total simulado, em segundos (base para o futuro calendário do jogo)
Simulation.time = 0

-- Descarta o tempo acumulado; chamar ao entrar num estado que simula o mundo
function Simulation.reset()
  accumulator = 0
end

-- Avança o mundo pelo tempo real `dt`, chamando step(STEP) a cada passo.
-- Se step devolver false, os passos restantes do frame são cancelados.
-- Os pulses de input (teclas de um frame só) valem apenas para o primeiro
-- passo do frame, para não disparar duas vezes. Devolve o número de passos.
function Simulation.advance(dt, step)
  accumulator = accumulator + math.min(dt, MAX_FRAME_TIME)

  local steps = 0
  local hiddenPulses
  while accumulator >= Simulation.STEP - SNAP do
    if steps == 1 then
      hiddenPulses = config.Input.hidePulses()
    end
    accumulator = accumulator - Simulation.STEP
    Simulation.time = Simulation.time + Simulation.STEP
    steps = steps + 1
    if step(Simulation.STEP) == false then break end
  end

  if hiddenPulses then
    config.Input.restorePulses(hiddenPulses)
  end
  return steps
end

return Simulation
