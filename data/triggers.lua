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
  text = "Você encontra uma nota adesiva no painel principal da nave:\n\n"
    .. "\"Não deu pra te esperar, o grupo ficou impaciente.\n\n"
    .. "As coordenadas para o Olho estão no mapa da nave.\n\n"
    .. "Estarei te esperando.\"",
},
}
