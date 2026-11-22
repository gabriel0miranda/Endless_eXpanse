return {
["Young Noobinobi"] =  {
  name = "Jovem Noobinobi",
  description = "Você cresceu em Coração de Mãe, mas acabou preso com sua mãe e seu padrasto na gigantesca colônia de férias que é o Refúgio de Merle. O Império Noobi encolheu, e a liberdade lhe pareceu mais próxima em um belo dia de primavera.\nCom a PP-2340 que sua mãe recebeu de herança (mas nunca pilotou) você parte em direção ao desconhecido. Escape do espaço Noobinobi, venda qualquer mercadoria que puder encontrar e assuma as rédeas do seu destino.",
  starting_system = "Eagle's Nest",
  starting_systemId = 1,
  starting_date = { year = 768, month = 5, day = 27, hour = 4 },
  starting_place = "Merle's Refuge",
-- Se não tiver starting place
-- x = 400,
-- y = 300,
  dificulty = "standard",
  starting_property = {
    {
      ship = true,
      flagShip = true,
      name = "Noite Branca",
      type = "PP-2340",
      weapons = {[1] = "Mining Laser", [2] = "Vacuum Machinegun", [3] = "Predator Missile", [4] = "Proximity Mine", [5] = "EMP"},
      cargo = {
        ["Cocaine"] = 12,
        ["Steel Sheets"] = 2,
      },
    },
  },
  starting_credits = 500,
  landedAt = false,
},
["Iron Baller"] =  {
  name = "Boleiro de Ferro",
  description = "Após 16 longos anos trabalhando na Bola de Ferro, você finalmente juntou dinheiro suficiente para mudar de profissão e deixar a Ballestra Inc.\nSua vida agora é incerta e solitária, mas a galáxia inteira está ao seu alcance.",
  starting_system = "Flag's Peak",
  starting_systemId = 4,
  starting_date = { year = 745, month = 3, day = 12, hour = 14 },
  starting_place = "Iron Ball",
-- Se não tiver starting place
-- x = 400,
-- y = 300,
  dificulty = "standard",
  starting_property = {
    {
      ship = true,
      flagShip = true,
      name = "Rastro de Ferrugem",
      type = "NN-Interceptor",
      weapons = {[1] = "Photon Cannon", [2] = "Vacuum Machinegun", [3] = "Predator Missile", [4] = "Proximity Mine", [5] = "EMP"},
      cargo = {
        ["Iron Ore"] = 12,
        ["Water"] = 21,
      },
    },
  },
  starting_credits = 800,
  landedAt = false,
},
["Lost Peregrine"] =  {
  name = "Peregrino Perdido",
  description = "Você se perdeu do grupo de peregrinos que iria até o sistema central da galáxia, 'O Olho', visitar o local de surgimento dos Bhikkhus, a raça anciã responsável por construir os buracos de minhoca e conectar os sistemas habitados da galáxia. Por sorte a nave emprestada pelo irmão Jiko ainda te aguardava na doca #2264 do porto espacial #7.",
  starting_system = "Passage",
  starting_systemId = 5,
  starting_date = { year = 750, month = 1, day = 1, hour = 6 },
  starting_place = "Lilium",
-- Se não tiver starting place
-- x = 400,
-- y = 300,
  dificulty = "standard",
  starting_property = {
    {
      ship = true,
      flagShip = true,
      name = "Corélia",
      type = "GHM-1",
      cargo = {
        ["Water"] = 50,
        ["Rice Crisp"] = 200,
        ["Clothing"] = 150,
      },
    },
  },
  starting_credits = 100,
  landedAt = { name = "Lilium"
  },
},
}
