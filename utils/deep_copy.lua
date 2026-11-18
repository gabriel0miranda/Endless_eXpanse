-- Cópia recursiva de tabelas de dados (sem metatables nem referências cíclicas).
-- Usada para que o estado do jogo nunca altere as tabelas de data/*.lua.
local function DeepCopy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for k, v in pairs(value) do
    copy[k] = DeepCopy(v)
  end
  return copy
end

return DeepCopy
