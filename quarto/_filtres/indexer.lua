-- indexer.lua — relève les étiquettes d'un chapitre et leurs numéros.
-- Appelé par _outils/pre-rendu.py :
--   quarto pandoc chap.qmd -L _filtres/indexer.lua -M chapitre=3 \
--          -M sortie=fichier.json -t plain -o /dev/null
local dossier = PANDOC_SCRIPT_FILE:match("(.*[/\\])") or "./"
package.path = dossier .. "?.lua;" .. package.path
local numerotation = require("numerotation")

function Pandoc(doc)
  local chap = doc.meta.chapitre and pandoc.utils.stringify(doc.meta.chapitre)
  if chap == "" then chap = nil end
  local _, etiquettes = numerotation.numeroter(doc, chap, false)
  -- le chapitre lui-même
  for _, b in ipairs(doc.blocks) do
    if b.t == "Header" and b.level == 1 and b.identifier ~= "" then
      etiquettes[b.identifier] = { num = chap or "", type = "chapitre",
                                   titre = pandoc.utils.stringify(b.content) }
    end
  end
  local sortie = pandoc.utils.stringify(doc.meta.sortie)
  local f = assert(io.open(sortie, "w"))
  f:write(pandoc.json.encode(etiquettes))
  f:close()
  return doc
end
