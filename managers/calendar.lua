-- Data e hora do jogo.
--
-- O relógio do mundo (WorldState.time) conta segundos de simulação. O
-- calendário converte esse relógio em segundos de jogo (multiplicando pela
-- escala de tempo) e soma a data inicial do cenário. Uma data é guardada como
-- um número só, os segundos de jogo desde 01/01/0 E.G. 00:00, e só vira
-- dia/mês/ano na hora de mostrar.
local Calendar = {}

local function data()
  return config.CalendarData
end

local MINUTE = 60
local HOUR   = 60 * MINUTE

local function dayLength()   return data().hoursPerDay * HOUR end
local function yearLength()  return data().monthsPerYear * data().daysPerMonth end  -- em dias

-- { year, month, day, hour, minute } → segundos de jogo. month e day começam em 1.
function Calendar.toSeconds(date)
  local days = (date.year or 0) * yearLength()
    + ((date.month or 1) - 1) * data().daysPerMonth
    + ((date.day or 1) - 1)
  return days * dayLength() + (date.hour or 0) * HOUR + (date.minute or 0) * MINUTE
end

-- Segundos de jogo → { year, month, day, hour, minute }
function Calendar.fromSeconds(seconds)
  local dayIndex  = math.floor(seconds / dayLength())
  local secOfDay  = seconds - dayIndex * dayLength()
  local dayOfYear = dayIndex % yearLength()
  return {
    year   = math.floor(dayIndex / yearLength()),
    month  = math.floor(dayOfYear / data().daysPerMonth) + 1,
    day    = dayOfYear % data().daysPerMonth + 1,
    hour   = math.floor(secOfDay / HOUR),
    minute = math.floor((secOfDay % HOUR) / MINUTE),
  }
end

-- Segundos de jogo correspondentes a `simSeconds` do relógio do mundo
function Calendar.toGameSeconds(simSeconds)
  return simSeconds * data().timeScale
end

-- E o inverso, para avançar o relógio do mundo por um tempo de jogo
function Calendar.toSimSeconds(gameSeconds)
  return gameSeconds / data().timeScale
end

-- Data atual, em segundos de jogo
function Calendar.now()
  return config.WorldState.startDate() + Calendar.toGameSeconds(config.WorldState.time())
end

-- "14/03/768 E.G." (ou "14 Nome 768 E.G." se o mês tiver nome)
function Calendar.formatDate(seconds)
  local d = Calendar.fromSeconds(seconds)
  local name = data().monthNames[d.month]
  if name then
    return string.format("%d %s %d %s", d.day, name, d.year, data().era)
  end
  return string.format("%02d/%02d/%d %s", d.day, d.month, d.year, data().era)
end

function Calendar.formatTime(seconds)
  local d = Calendar.fromSeconds(seconds)
  return string.format("%02d:%02d", d.hour, d.minute)
end

function Calendar.format(seconds)
  return Calendar.formatDate(seconds) .. " " .. Calendar.formatTime(seconds)
end

-- Quanto tempo de jogo um descanso iniciado em `seconds` dura: até a próxima
-- restUntilHour que esteja a pelo menos restMinHours de distância
function Calendar.restDuration(seconds)
  local dayStart = math.floor(seconds / dayLength()) * dayLength()
  local wake = dayStart + data().restUntilHour * HOUR
  while wake - seconds < data().restMinHours * HOUR do
    wake = wake + dayLength()
  end
  return wake - seconds
end

return Calendar
