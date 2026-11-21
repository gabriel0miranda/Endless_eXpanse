-- Serializa tabelas Lua de dados simples em texto e de volta.
--
-- O texto é código Lua ("return { ... }") com chaves ordenadas, fácil de ler
-- e de comparar entre saves. Funções, userdata (corpos do Box2D, fontes...)
-- e referências cíclicas são recusadas com um erro que diz onde estão.
local Serialize = {}

local function encodeNumber(n)
  if n ~= n then return "0/0" end
  if n == math.huge then return "1/0" end
  if n == -math.huge then return "-1/0" end
  if n == math.floor(n) and math.abs(n) < 2^53 then
    return string.format("%d", n)
  end
  return string.format("%.17g", n)
end

local function sortKeys(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta < tb end
  return a < b
end

local encodeValue

local function encodeTable(t, indent, path, seen)
  if seen[t] then error("referência cíclica em " .. path, 0) end
  seen[t] = true

  local keys = {}
  for k in pairs(t) do
    local tk = type(k)
    if tk ~= "string" and tk ~= "number" then
      error("chave do tipo " .. tk .. " em " .. path, 0)
    end
    keys[#keys + 1] = k
  end
  table.sort(keys, sortKeys)

  if #keys == 0 then
    seen[t] = nil
    return "{}"
  end

  local inner = indent .. "  "
  local lines = {}
  for _, k in ipairs(keys) do
    local keyText
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      keyText = k
    elseif type(k) == "string" then
      keyText = "[" .. string.format("%q", k) .. "]"
    else
      keyText = "[" .. encodeNumber(k) .. "]"
    end
    local childPath = path .. "." .. tostring(k)
    lines[#lines + 1] = inner .. keyText .. " = " .. encodeValue(t[k], inner, childPath, seen) .. ","
  end
  seen[t] = nil
  return "{\n" .. table.concat(lines, "\n") .. "\n" .. indent .. "}"
end

encodeValue = function(v, indent, path, seen)
  local tv = type(v)
  if tv == "number" then return encodeNumber(v) end
  if tv == "string" then return string.format("%q", v) end
  if tv == "boolean" then return tostring(v) end
  if tv == "table" then
    if getmetatable(v) then error("tabela com metatable em " .. path, 0) end
    return encodeTable(v, indent, path, seen)
  end
  error("valor do tipo " .. tv .. " em " .. path, 0)
end

-- Devolve o texto; lança erro se `value` tiver algo que não é dado simples
function Serialize.encode(value)
  return "return " .. encodeValue(value, "", "root", {}) .. "\n"
end

-- Devolve a tabela, ou nil e a mensagem de erro. O texto roda num ambiente
-- vazio: um save não consegue chamar nenhuma função do jogo ou do Lua.
-- O modo "t" recusa bytecode, que poderia burlar o ambiente vazio.
function Serialize.decode(text)
  local env = {}
  local chunk, err = load(text, "save", "t", env)
  if not chunk then return nil, err end
  if setfenv then setfenv(chunk, env) end  -- LuaJIT/5.1: garante o ambiente
  local ok, result = pcall(chunk)
  if not ok then return nil, result end
  if type(result) ~= "table" then return nil, "o save não contém uma tabela" end
  return result
end

return Serialize
