-- numerotation.lua — numérotation des éléments du livre, calquée sur les
-- compteurs de livrejs.cls. Partagé par :
--   * indexer.lua  (avant le rendu : table des étiquettes de tout le livre) ;
--   * livrejs.lua  (rendu HTML : numéros affichés dans chaque page).
-- En PDF, c'est LaTeX qui numérote ; ces règles doivent donc rester
-- identiques à celles de la classe.

local M = {}

-- Environnement -> compteur (Théorème, Proposition, Lemme et Corollaire
-- partagent le compteur « thm », comme dans livrejs.cls).
M.compteur = {
  theorem = "thm", proposition = "thm", lemma = "thm", corollary = "thm",
  definition = "definition", example = "example", remark = "remark",
  historical = "historical", secondaire = "secondaire", outil = "outil",
  algorithme = "algorithme", axiome = "axiome", exercice = "exercice",
}

M.nom = {
  theorem = "Théorème", proposition = "Proposition", lemma = "Lemme",
  corollary = "Corollaire", definition = "Définition", example = "Exemple",
  remark = "Remarque", historical = "Note historique",
  secondaire = "Pour la classe", outil = "Outil", algorithme = "Algorithme",
  axiome = "Axiome", exercice = "Exercice",
}

function M.classe_env(div)
  for _, c in ipairs(div.classes) do
    if M.compteur[c] then return c end
  end
end

-- Environnements mathématiques numérotés par LaTeX
local NUMEROTES = { equation = true, align = true, gather = true,
                    multline = true, flalign = true, alignat = true }

-- Renvoie, pour un environnement mathématique LaTeX, la liste des lignes
-- numérotées : { {label = "eq:x" ou nil}, ... }.
function M.equations(tex)
  local env = tex:match("^%s*\\begin{([%a%*]+)}")
  if not env or not NUMEROTES[env] then return {} end
  local corps = tex:gsub("^%s*\\begin{%a+%*?}", ""):gsub("\\end{%a+%*?}%s*$", "")
  if env == "equation" or env == "multline" then
    return { { label = corps:match("\\label{([^}]*)}") } }
  end
  local res = {}
  corps = corps .. "\\\\"
  for ligne in corps:gmatch("(.-)\\\\") do
    if ligne:match("%S") and not ligne:match("\\nonumber")
       and not ligne:match("\\notag") then
      table.insert(res, { label = ligne:match("\\label{([^}]*)}") })
    end
  end
  return res
end

local function est_tex(f)
  return f == "tex" or f == "latex"
end

-- Numérote un document (un chapitre). `chapitre` est le numéro affiché
-- (« 3 ») ou nil pour un chapitre non numéroté. Les numéros sont posés
-- dans l'attribut « num » des éléments ; si `math_html` est vrai, les
-- environnements mathématiques numérotés sont remplacés par des formules
-- MathJax munies de \tag. Renvoie le document et la table des étiquettes.
function M.numeroter(doc, chapitre, math_html)
  local c = {}
  local sec = { 0, 0 }
  local etiquettes = {}
  local prefixe = chapitre and (chapitre .. ".") or ""

  local function suivant(nom)
    c[nom] = (c[nom] or 0) + 1
    return prefixe .. c[nom]
  end

  local function noter(id, num, type)
    if id and id ~= "" then
      etiquettes[id] = { num = num, type = type }
    end
  end

  local function math_env(texte)
    local eqs = M.equations(texte)
    if #eqs == 0 then return nil end
    local nums = {}
    for _, e in ipairs(eqs) do
      local n = suivant("equation")
      table.insert(nums, n)
      noter(e.label, n, "equation")
    end
    if not math_html then return nil end
    -- MathJax : \tag explicite, ancres pour les renvois
    local k = 0
    local ancres = {}
    local t = texte:gsub("\\label{([^}]*)}", function(l)
      table.insert(ancres, pandoc.Span({}, { id = l }))
      return ""
    end)
    t = t:gsub("\\begin{(%a+)}", "\\begin{%1*}", 1)
         :gsub("\\end{(%a+)}%s*$", "\\end{%1*}")
    if #nums == 1 and (t:match("^%s*\\begin{equation") or
                       t:match("^%s*\\begin{multline")) then
      t = t:gsub("\\end{", "\\tag{" .. nums[1] .. "}\\end{", 1)
    else
      t = t .. "\\\\"
      t = t:gsub("(.-)\\\\", function(ligne)
        if ligne:match("\\end{") then return ligne end
        if ligne:match("%S") and not ligne:match("\\nonumber")
           and not ligne:match("\\notag") then
          k = k + 1
          return ligne .. "\\tag{" .. nums[k] .. "}\\\\"
        end
        return ligne .. "\\\\"
      end)
    end
    local res = ancres
    table.insert(res, pandoc.Math("DisplayMath", t))
    return res
  end

  local filtre = {
    traverse = "topdown",
    Header = function(h)
      if h.level == 1 or h.classes:includes("unnumbered") then return nil end
      local n
      if h.level == 2 then
        sec[1] = sec[1] + 1; sec[2] = 0
        n = prefixe .. sec[1]
      elseif h.level == 3 then
        sec[2] = sec[2] + 1
        n = prefixe .. sec[1] .. "." .. sec[2]
      else
        return nil
      end
      h.attributes["num"] = n
      noter(h.identifier, n, "section")
      return h
    end,
    Div = function(d)
      local env = M.classe_env(d)
      local n, type
      if env then
        n = suivant(M.compteur[env]); type = env
      elseif d.identifier:match("^fig:") then
        n = suivant("figure"); type = "figure"
      elseif d.identifier:match("^tab:") then
        n = suivant("table"); type = "table"
      else
        return nil
      end
      d.attributes["num"] = n
      noter(d.identifier, n, type)
      return d
    end,
    CodeBlock = function(cb)
      if cb.attributes["caption"] then
        cb.attributes["num"] = suivant("listing")
        noter(cb.identifier, cb.attributes["num"], "listing")
        return cb
      end
    end,
    RawInline = function(r)
      if est_tex(r.format) then return math_env(r.text) end
    end,
    RawBlock = function(r)
      if est_tex(r.format) then
        local res = math_env(r.text)
        if res then return pandoc.Para(res) end
      end
    end,
  }
  doc = doc:walk(filtre)
  return doc, etiquettes
end

return M
