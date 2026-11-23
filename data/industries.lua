-- Indústrias: receitas de produção e consumo dos mercados.
--
-- Cada indústria consome `inputs` e produz `outputs`, em unidades por hora de
-- jogo. Sem insumo suficiente, ela trabalha na fração que o estoque permite.
-- Uma indústria com várias receitas independentes as lista em `recipes`: a
-- falta de insumo numa receita não para as outras.
-- Indústria sem `inputs` produz do nada (mina, fazenda); sem `outputs`, só
-- consome (população). Os landables usam as indústrias em
-- `market.industries = { [chave] = quantidade }` (data/landables.lua).
--
-- Valores provisórios, para o balanceamento.
return {
-- Extração e cultivo
["Iron Mine"] = {
  name    = "Mina de Ferro",
  outputs = { ["Iron Ore"] = 10 },
},
["Sulfur Vents"] = { name    = "Extração de Enxofre", outputs = { ["Sulfur"] = 12 },
},
["Rice Paddies"] = {
  name    = "Arrozais",
  inputs  = { ["Water"] = 6, ["Phosphorus"] = 1 },
  outputs = { ["Rice Grain"] = 30 },
},
["Water Plant"] = {
  name    = "Usina de Água",
  outputs = { ["Water"] = 10 },
},
["Phosphorus Extractor"] = {
  name    = "Extração de Fósforo",
  outputs = { ["Phosphorus"] = 8 },
},
["Silicon Mine"] = {
  name    = "Mina de Silício",
  outputs = { ["Silicon"] = 15 },
},
["Hemp Greenhouse"] = {
  name    = "Estufa de Cânhamo",
  inputs = { ["Water"] = 10, ["Phosphorus"] = 2, ["Energy Cell"] = 4},
  outputs = { ["Hemp"] = 35},
},

-- Transformação
["Steel Mill"] = {
  name    = "Laminadora de Aço",
  inputs  = { ["Iron Ore"] = 10, ["Carbon"] = 2 },
  outputs = { ["Steel Sheets"] = 5 },
},
["Smelter"] = {
  name    = "Fundição",
  recipes = {
    { inputs = { ["Silver Ore"] = 6 },                    outputs = { ["Silver Ingot"] = 3 } },
    { inputs = { ["Gold Ore"] = 6 },                      outputs = { ["Gold Ingot"] = 3 } },
    { inputs = { ["Titanium Ore"] = 4, ["Sulfur"] = 1 },  outputs = { ["Titanium Alloy"] = 1 } },
  },
},
["Solar Array"] = {
  name    = "Painéis Solares",
  inputs  = { ["Water"] = 4, ["Silicon"] = 2 },
  outputs = { ["Energy Cell"] = 6 },
},
["Rice Crisp Factory"] = {
  name    = "Fábrica de Biscoito de Arroz",
  inputs  = { ["Rice Grain"] = 10 },
  outputs = { ["Rice Crisp"] = 8 },
},
["Textile Mill"] = {
  name    = "Tecelagem",
  inputs  = { ["Hemp"] = 2, ["Water"] = 2 },
  outputs = { ["Clothing"] = 3 },
},
["Cocaine Lab"] = {
  name    = "Laboratório Clandestino",
  inputs  = { ["Sulfur"] = 2, ["Water"] = 1 },
  outputs = { ["Cocaine"] = 2 },
},

-- Consumo
["Luxury Colony"] = {
  name    = "Colônia de Férias",
  inputs  = { ["Rice Crisp"] = 6, ["Clothing"] = 2, ["Water"] = 8, ["Cocaine"] = 1, ["Silver Ingot"] = 1 },
},
["Farming Population"] = {
  name    = "População Rural",
  inputs  = { ["Steel Sheets"] = 1, ["Clothing"] = 2 },
},
["Military Base"] = {
  name    = "Base Militar",
  inputs  = { ["Steel Sheets"] = 3, ["Titanium Alloy"] = 1, ["Water"] = 6, ["Rice Crisp"] = 4 },
},
["Cloud City"] = {
  name    = "Cidade nas Nuvens",
  inputs  = { ["Steel Sheets"] = 2, ["Carbon"] = 1, ["Water"] = 4, ["Rice Crisp"] = 3 },
},
["Pilgrim Hub"] = {
  name    = "Polo de Peregrinação",
  inputs  = { ["Gold Ore"] = 1, ["Water"] = 4 },
},
}
