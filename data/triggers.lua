-- Gatilhos: mensagens que aparecem quando o jogador faz certas ações.
--
-- Cada gatilho responde a um evento e só dispara se todas as condições
-- valerem. Os disparos ficam no WorldState (e no save), para um gatilho
-- `once` não se repetir. Ver managers/triggers.lua.
--
-- Campos:
--   event       "depart" (clicou em decolar) ou "land" (pousou)
--   once        true: dispara uma vez só no jogo
--   conditions  todas opcionais:
--                 start    chave do cenário inicial em data/starts.lua
--                 landable chave do landable onde a nave está
--                 system   id do sistema atual em data/systems.lua
--                 chance   probabilidade de disparar, de 0 a 1
--   speaker     quem fala (título da caixa de diálogo)
--   text        a mensagem
return {
["jiko_departure"] = {
  event = "depart",
  once = true,
  conditions = { start = "Lost Peregrine", landable = "Lilium" },
  speaker = "Irmão Jiko",
  -- Texto provisório
  text = "Uma mensagem gravada pisca no painel da Corélia antes da decolagem.\n\n"
    .. "\"Se você está ouvindo isto, perdeu a caravana. Não fique triste: os Guardiões da Passagem só abrem o caminho uma vez a cada ciclo, e não pudemos esperar. "
    .. "A nave é sua até nos reencontrarmos.\n\n"
    .. "O Olho fica além das rotas que você conhece. Siga pelo buraco de minhoca para Flag's Peak e pergunte pelo caminho nas estações. "
    .. "Os comerciantes sabem mais do que dizem, e créditos soltam a língua de qualquer um. "
    .. "Leve carga: uma nave vazia é uma viagem desperdiçada.\n\n"
    .. "Nos vemos no Olho, peregrino.\"",
},
}
