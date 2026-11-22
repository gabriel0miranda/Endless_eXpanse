return {
["Merle's Refuge"] =  {
  name = "Refúgio de Merle",
  description = "Esse planeta serve como um paraíso tranquilo aos noobinianos ricos, aposentados e desocuptados. A segurança absoluta do sistema e o clima temperado do planeta criaram uma população verdadeiramente hedonista. Esse nível de bem estar só é possível por conta do mercado extremamente lucrativo de mineração.",
  -- Com orbitAngle e orbitRadius essas posições chumbadas deixam de ser necessárias
  --x =  200,
  --y =-1100,
  orbitRadius = 2900,
  orbitAngle  = 2,
  orbitSpeed  = 0.005,
  radius = 600,
  type = "planet",
  color = {25/255, 134/255, 201/255},
  buttons = {
    spaceport = { description = "O porto espacial é cheio até a boca de noobinianos, é sempre alta temporada no Refúgio de Merle."},
    bar       = { description = "Um bar bem chique e noir. A nobreza noobinobi aprecisa momentos de descontração calmos e elegantes." },
    bank      = { description = "Essa é uma agência bancária gigantesca, suas colunas brancas se impõem sobre você, e o peso do dinheiro é materializado na forma de uma estátua enorme de touro suspendida num pedestal grosso."},
    trade     = {},
--    shipyard  = {},
  },
--  shipyard = {
--    stock = {
--    "PP-2340","NN-Interceptor","NN-Gunship","NN-Dreadnought"
--    },
--  },
  market = {
    capacity = 20000,
    industries = { ["Luxury Colony"] = 2 },  -- data/industries.lua
    stock = {},
  },
},
["Mother's Heart"] =  {
  name = "Coração de Mãe",
  description = "O planeta principal do Empério Noobi, um regime pretencioso que consolidou o povo Noobinobi. O Emperio tentou, por vários anos, invadir um sistemas livres que se estendem além da Parede, mas acabou falido e numa onda de fome que só se resolveu quando a Grande Frota Noobi (GNN) redirecionou suas tropas para tender os campos do Coração de Mãe",
  --x =  1200,
  --y = -1800,
  orbitRadius = 3500,
  orbitAngle  = 1,
  orbitSpeed  = 0.005,
  radius = 900,
  type = "planet",
  color = {78/255, 183/255, 64/255},
  buttons = {
    spaceport = { description = "Um enorme campo verde se extente em todas as direções em volta do porto espacial. Daqui você pode pegar um trem bala direto para a capital do Coração de Mãe." },
    bar       = { description = "O cheiro de grama fresca e o vento do campo é extremamente agradável quando se tenta aproveitar uma boa bebida. Homens e mulheres de todas as castas se reunem nos bares do Coração de Mãe." },
    bank      = { description = "Esta agência do Banco Galático é arejada e espaçosa, alguns clientes trazem seus animais para negociar empréstimos rurais."},
    trade     = {},
  },
  market = {
    capacity = 20000,
    industries = { ["Rice Paddies"] = 1, ["Water Plant"] = 2, ["Hemp Greenhouse"] = 1, ["Textile Mill"] = 1, ["Farming Population"] = 2 },  -- data/industries.lua
    stock = {},
  },
},
["Trading Station"] = {
  name = "Estação de Troca",
  description = "Essa é uma estação de troca, muitas câmaras de troca e louges esperam por grandes câmbios de bens, favores e poder.",
  --x = -900,
  --y = -400,
  orbitRadius = 1800,
  orbitAngle  = 1,
  orbitSpeed  = 0.05,
  radius = 150,
  type = "station",
  color = {1/255, 125/255, 137/255},
  buttons = {
    spaceport = { description = "A doca da estação é minúscula, a maioria dos visitantes nem mesmo para para fazer negócios." },
    bar       = { description = "Um bar escuro e neblinoso, apenas os negócios mais obscuros se realizam nas cabines privadas." },
    bank      = { description = "Uma pequena agência do Banco Galático. A atendente entediada do outro lado do vidro chama os clientes por senha."},
    trade     = { description = "O som de comércio, dinheiro e telefones tocando monta uma sinfonia aterrorizante, você se recolhe e senta em um dos terminais de troca, o uso dos headphones abafadores dos terminais é uma necessidade aqui."},
  },
  market = {
    capacity = 20000,
    stock = {},
  },
},
["Mining Depot"] =   {
  name        = "Depósito de Mineração",
  description = "Um enorme armazem de minérios que inicia o caminho do metal pela indústria galática. Aguardando silenciosamente pelos cargueiros que vendem e compram minérios.",
  --x      = 1200,
  --y      = 600,
  orbitRadius = 2900,
  orbitAngle  = 1,
  orbitSpeed  = 0.01,
  radius = 230,
  type   = "station",
  color  = {170/255, 154/255, 3/255},
  buttons = {
  trade = { description = "Uma doca de compra e venda. Minérios estão sempre em alta demanda aqui." },
  },
  market = {
  capacity = 20000,
  industries = { ["Smelter"] = 1 },  -- data/industries.lua
  stock = {},
  },
},
["Metal Refinery"] = {
  name = "Refinaria de Metal",
  description = "Uma fundição flutuante que opera quase que autonomamente. Apenas alguns funcionários residem na estação e gerenciam um pequeno armazem de trocas anexado à estação.",
  --x = 500,
  --y = -800,
  orbitRadius = 1800,
  orbitAngle  = 1,
  orbitSpeed  = 0.02,
  radius = 180,
  type = "station",
  color = {1/255, 125/255, 137/255},
  buttons = {
    spaceport = { description = "A doca é simples e eficiente." },
    trade     = {},
  },
  market = {
    capacity = 20000,
    industries = { ["Steel Mill"] = 1 },  -- data/industries.lua
    stock = {},
  },
},
["Shipyard"] = {
  name = "Estaleiro",
  description = "O Estaleiro é um lugar bastante pragmático. Elevadores gigantes rotacionam as naves em cada doca, trazendo aquelas escolhidas pelos compradores em um computador falante.",
  --x = -500,
  --y = 900,
  orbitRadius = 2900,
  orbitAngle  = 2,
  orbitSpeed  = 0.005,
  radius = 230,
  type = "station",
  color = {1/255, 125/255, 137/255},
  buttons = {
    bar       = { description = "Um pequeno café serve drinks diversos e comida de dedo para os clientes que aguardam reparos e despachos de documentos." },
    bank      = { description = "Um mínusculo caixa eletrônico do Banco Galático."},
    shipyard  = {},
  },
  shipyard = {
    stock = {
    "PP-2340","NN-Interceptor","NN-Gunship","NN-Dreadnought"
    },
  },
},
["Golden Fortress"] = {
  name = "Fortaleza Dourada",
  description = "A Fortaleza Dourada é um massivo planeta artifical que serve como último bastião de defesa do Empério Noobi. A fortaleza repele piratas o tempo todo com facilidade, mas nunca enfrentou um ataque massivo coordenado.",
  --x = -2000,
  --y = 0,
  orbitRadius = 4000,
  orbitAngle  = 1,
  orbitSpeed  = 0.009,
  radius = 500,
  type = "planet",
  color = {239/255, 221/255, 59/255},
  buttons = {
    spaceport = { description = "O Porto Espacial da Fortaleza Dourada é militarizado por natureza, milhares de soldados noobinobi se locomovem com velocidade e precisão por entre as naves." },
    bank      = { description = "Uma agência comum do Banco Galático. O banheiro está em reformas."},
  },
},
["Iron Ball"] = {
  name = "Bola de Ferro",
  description = "Um planeta rochoso rico em óxido de ferro. Serve como prisão militar e ponto de abastecimento da corporação militar privada Ballestra Inc. Todo o planeta é coberto de ferrugem e poeira, a respiração só é possível com máscaras de filtragem pesada e sair na superfície sem um traje adequado pode levar à morte em minutos.",
  --x = -2000,
  --y = 0,
  orbitRadius = 3500,
  orbitAngle  = 1,
  orbitSpeed  = 0.009,
  radius = 1800,
  type = "planet",
  color = {0.6,0.2,0.2,1},
  buttons = {
    spaceport = { description = "O porto de Bola de Ferro é um local de vigilância constante, guardas e robôs armados checam constantemente a identidade e a carga de todas as naves que pousam aqui. É um péssimo lugar para ser pego com um fugitivo." },
    bank      = { description = "Uma agência comum do Banco Galático. Neste planeta uma construção como essa é um alívio para os olhos."},
    bar       = { description = "Atrás do porto espacial, este boteco é frequentado principalmente por mercenários de folga e prisoneiros recém libertos. O clima que paira é pesado e silencioso, as pessoas bebem sozinhas ou em pequenos grupos." },
    trade     = {}
  },
  market = {
  capacity = 20000,
  industries = { ["Iron Mine"] = 1, ["Military Base"] = 1 },  -- data/industries.lua
  stock = {},
  },
},
["Flutura"] = {
  name = "Flutura",
  description = "Um planeta rochoso com uma atmosfera extremamente densa. A colonização aqui ocorreu nas nuvens, evitando a pressão e temperatura elevadas na superfície. Flutura foi a capital galática do Califado Hermético do Sol Amarelo por muitos anos, porém depois da invasão noobiniana de 755 E.G. a ordem religiosa desapareceu, muitos ainda os culpam pelo início do conflito.",
  --x = -2000,
  --y = 0,
  orbitRadius = 9000,
  orbitAngle  = 1,
  orbitSpeed  = 0.01,
  radius = 650,
  type = "planet",
  color = {0.5,0.4,0.01,1},
  buttons = {
    spaceport = { description = "Uma enorme plataforma flutuante serve como porto espacial em Flutura. O espaço para naves estacionadas é pequeno, mas é sempre possível planar em volta do porto gastanto pouquíssimo combustível." },
    bar       = { description = "Flutura possui um dos maiores centros de divertimento adulto da galáxia, apesar de um pouco depredado atualmente. Uma formação de prédios flutuantes constitui uma verdadeira ilha de bebederia, jogos e sexo nas alturas." },
    trade     = {}
  },
  market = {
  capacity = 20000,
  industries = { ["Sulfur Vents"] = 1, ["Hemp Greenhouse"] = 1, ["Cocaine Lab"] = 1, ["Cloud City"] = 1 },  -- data/industries.lua
  stock = {},
  },
  },
["Lilium"] = {
  name = "Lírio",
  description = "O Lírio foi um dos primeiros planetas habitados a receber a visita dos Bhikkhus, no início da Época Galática. Os visitantes trouxeram consigo inovações tecnológicas tão incríveis que os lirianos os tomaram como deuses, ajudando os Bhikkus em sua jornada para unir toda a galáxia habitada. Foi apenas depois de 300 anos que os Bhikkus finalmente conseguiram dissuadir a população local da crença de que eles eram seres divinos. Hoje o planeta é um grande produtor de alimentos e se posiciona em uma rota comercial extremamente lucrativa, além de servir como um polo histórico e cultural da galáxia.",
  --x = -2000,
  --y = 0,
  orbitRadius = 10000,
  orbitAngle  = 1,
  orbitSpeed  = 0.04,
  radius = 400,
  type = "planet",
  color = {0.5,0.3,0.8,1},
  buttons = {
    spaceport = { description = "Lírio tem 8 portos espaciais, sendo o maior deles o #7. Este porto fica localizado no topo de um platô gigantesco, o ar é rarefeito e após o pouso as tripulações precisam aguardar por um tubo de transporte (praticamente uma esteira transportadora em formato de tobogã) para entrarem na área interna do porto sem sofrerem hipóxia." },
    bar       = { description = "A bebida principal de Lírio é o saquê de arroz. Um bar de saquê liriano possui um balcão, com bancos de um lado e garrafas de outro, não é da cultura liriana beber em mesas privadas, portanto os bares são bem pequenos e intimistas."},
    trade     = {}
  },
  market = {
  capacity = 20000,
  industries = { ["Rice Paddies"] = 1, ["Water Plant"] = 1, ["Hemp Greenhouse"] = 1, ["Rice Crisp Factory"] = 1, ["Textile Mill"] = 1, ["Pilgrim Hub"] = 1 },  -- data/industries.lua
  stock = {},
  },
  },
}
