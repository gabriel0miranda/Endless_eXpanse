-- Calendário da Época Galática (E.G.)
--
-- Baseado no calendário do planeta Sangha, destruído logo após a expansão dos Bhikkhus pela galáxia, a hora 0, do dia 1, do mês 1 do ano 0 é a data em que Sangha foi engolido pelo buraco negro Maya, no centro da galáxia. O ano tem 11 meses de 58 dias (638 dias); o dia, 24 horas.
return {
  era           = "E.G.",
  monthsPerYear = 11,
  daysPerMonth  = 58,
  hoursPerDay   = 24,

  -- Nomes dos meses, na ordem. Vazio: a data sai só com números (14/03/768).
  monthNames    = {"Jyeshta", "Ashada", "Shravana", "Bhadrapada", "Ashwina", "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna", "Chaitra"},

  -- Segundos de jogo por segundo real em voo (60: 1 s real = 1 min de jogo)
  timeScale     = 60,

  -- Descanso: dorme até esta hora do dia seguinte, com um mínimo de horas
  restUntilHour = 6,
  restMinHours  = 4,
}
