-- Missões: trabalhos oferecidos no bar e missões de história.
--
-- Os trabalhos do bar são gerados por systems/missions.lua a partir dos
-- modelos em `jobs`. Cada bar oferece de `offers.min` a `offers.max`
-- trabalhos, renovados a cada `offers.refreshDays` dias de jogo.
--
-- Tipos de trabalho:
--   delivery    entrega de carga: o contratante põe a carga no porão, e o
--               jogador a leva até um landable de outro lugar
--   procure     encomenda: o jogador traz N unidades de um item que as
--               indústrias do contratante consomem
--   bounty      caça a piratas: destruir N piratas num sistema e voltar ao
--               contratante para receber
--   passengers  passageiros: levar pessoas a outro landable; ocupam os
--               beliches da nave (`bunks` em data/ships.lua)
--
-- Prazo vencido ou desistência: a missão falha, a carga continua no porão,
-- os passageiros desembarcam e a reputação com a facção do contratante cai.
-- Missão cumprida aumenta a reputação. A facção de um landable vem do campo
-- `faction` dele em data/landables.lua ou, sem o campo, da facção de maior
-- peso na população do sistema.
--
-- Textos: {chave} é trocado pelo valor da oferta. Chaves disponíveis:
--   {item} {quantity} {count} {dest} {destSystem} {origin} {system}
--   {reward} {deadline} {passengers}
--
-- Valores provisórios, para o balanceamento.
return {
  offers = {
    min         = 2,
    max         = 4,
    refreshDays = 1,
    maxJumps    = 3,   -- distância máxima do destino, em saltos
  },

  reputation = {
    success = 1,
    bounty  = 2,    -- caça a piratas cumprida
    failure = -3,   -- prazo vencido ou desistência
  },

  jobs = {
    delivery = {
      label  = "Entrega",
      weight = 3,
      -- Fração do espaço livre no porão da nave ativa que a carga ocupa
      cargoFraction = { 0.1, 0.4 },
      reward   = { base = 250, perJump = 300, perVolume = 2 },
      deadline = { baseDays = 1, perJumpDays = 1 },
      title = "Entrega de {item} para {dest}",
      text  = "Um despachante de macacão manchado se aproxima do balcão. \"Tenho {quantity} de {item} que precisam chegar a {dest}, em {destSystem}, até {deadline}. Pago {reward} cr na entrega.\"",
    },
    procure = {
      label  = "Encomenda",
      weight = 2,
      quantity = { 5, 30 },
      -- Recompensa = valor base dos itens × markup
      markup   = 1.6,
      deadline = { days = 4 },
      title = "Encomenda de {item}",
      text  = "A gerente de compras de {origin} divide a mesa com você. \"Estamos sem {item}. Traga {quantity} unidades até {deadline} e eu pago {reward} cr pelo lote.\"",
    },
    bounty = {
      label  = "Caça",
      weight = 1,
      count    = { 1, 3 },
      reward   = { perKill = 700 },
      deadline = { days = 3 },
      title = "Caça a piratas em {system}",
      text  = "Um sujeito com cicatrizes de queimadura nas mãos fala baixo. \"Piratas andam atacando nossos cargueiros em {system}. Destrua {count} deles e volte aqui até {deadline}. São {reward} cr.\"",
    },
    passengers = {
      label  = "Passageiros",
      weight = 2,
      passengers = { 1, 4 },
      reward   = { base = 150, perJump = 200, perPassenger = 120 },
      deadline = { baseDays = 1, perJumpDays = 1 },
      title = "Passageiros para {dest}",
      text  = "Um grupo de {passengers} viajante(s) com malas gastas pergunta se há lugar na sua nave. \"Precisamos chegar a {dest}, em {destSystem}, até {deadline}. Juntamos {reward} cr para a passagem.\"",
    },
  },

  -- Missões de história, iniciadas por gatilhos (`startMission` em
  -- data/triggers.lua). Objetivo "reach": entrar no sistema `system`.
  story = {
    reach_eye = {
      title     = "Chegar ao Olho",
      text      = "O irmão Jiko espera por você no Olho, o sistema mais próximo do núcleo da galáxia.",
      objective = "reach",
      system    = 6,
      reward    = 0,
    },
  },
}
