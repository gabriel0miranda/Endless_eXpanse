-- Forma da galáxia no mapa (ui/galaxy_map_ui.lua).
--
-- A galáxia é uma espiral de braços logarítmicos em volta do núcleo, no
-- ponto (0, 0). Os braços servem de fundo do mapa e de guia para posicionar
-- os sistemas: `mapX`/`mapY` de cada sistema em data/systems.lua são escritos
-- à mão, perto de um braço. Longe do núcleo os braços ficam isolados uns dos
-- outros; perto dele os sistemas se interligam.
--
-- Um ponto do braço i à distância r do núcleo fica no ângulo
--   phase + i * 2π / arms - winding * ln(radius / r)
-- (graus em `phase`; ângulo 0 aponta para o leste e cresce para o sul,
-- porque o y da tela cresce para baixo).
return {
  arms    = 5,
  radius  = 1000,   -- raio da borda da galáxia, em unidades do mapa
  core    = 90,     -- raio do núcleo brilhante
  winding = 2.2,    -- quanto os braços se enrolam (maior = mais voltas)
  phase   = 140.5,  -- ângulo do braço 0 na borda; o braço 0 é o dos Noobi
}
