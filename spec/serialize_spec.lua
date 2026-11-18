local Serialize = require("utils.serialize")

describe("Serialize", function()
  it("devolve a mesma tabela depois de codificar e decodificar", function()
    local data = {
      version = 1,
      time = 1234.5678901234567,
      flag = false,
      name = "Refúgio de \"Merle\"\n",
      list = { 1, 2, 3 },
      systems = { ["4"] = { landables = { ["Merle's Refuge"] = { phase = -2.5 } } } },
      [7] = "chave numérica",
      empty = {},
    }
    local back = assert(Serialize.decode(Serialize.encode(data)))
    assert.are.same(data, back)
  end)

  it("gera o mesmo texto para a mesma tabela (chaves ordenadas)", function()
    local a = { b = 1, a = 2, c = { z = 1, y = 2 } }
    local b = { c = { y = 2, z = 1 }, a = 2, b = 1 }
    assert.are.equal(Serialize.encode(a), Serialize.encode(b))
  end)

  it("recusa funções e diz onde estão", function()
    local ok, err = pcall(Serialize.encode, { player = { inventory = { add = function() end } } })
    assert.is_false(ok)
    assert.matches("root.player.inventory.add", err, 1, true)
  end)

  it("recusa referências cíclicas", function()
    local t = {}
    t.self = t
    assert.has_error(function() Serialize.encode(t) end)
  end)

  it("aceita a mesma tabela em dois lugares (sem ciclo)", function()
    local shared = { x = 1 }
    local back = assert(Serialize.decode(Serialize.encode({ a = shared, b = shared })))
    assert.are.same({ a = { x = 1 }, b = { x = 1 } }, back)
  end)

  it("roda o save num ambiente vazio", function()
    local data, err = Serialize.decode("return { x = os.exit() }")
    assert.is_nil(data)
    assert.is_string(err)
  end)

  it("recusa texto que não é uma tabela", function()
    assert.is_nil((Serialize.decode("return 42")))
    assert.is_nil((Serialize.decode("isso não é lua {")))
  end)
end)
