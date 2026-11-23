-- ═══════════════════════════════════════════════════════════════════════
--  livrejs.lua — filtre Quarto du livre
--
--  PDF  : traduit le Markdown en LaTeX pour livrejs.cls (environnements
--         theorem, exercice, solution, historical..., figures TikZ,
--         tableaux booktabs, listings) ; LaTeX numérote et renvoie.
--  HTML : produit la même structure en HTML (styles/livrejs.scss), avec
--         la numérotation de la classe (_filtres/numerotation.lua) et les
--         renvois entre chapitres (_etiquettes.json, cf. pre-rendu.py).
-- ═══════════════════════════════════════════════════════════════════════
local dossier = PANDOC_SCRIPT_FILE:match("(.*[/\\])") or "./"
package.path = dossier .. "?.lua;" .. package.path
local numerotation = require("numerotation")

local LATEX = FORMAT:match("latex") ~= nil
local HTML = FORMAT:match("html") ~= nil

local racine = "."
if quarto and quarto.project and quarto.project.directory then
  racine = quarto.project.directory
end

local function avertir(msg)
  io.stderr:write("[livrejs] " .. msg .. "\n")
end

local index = { fichiers = {}, etiquettes = {}, figures = {} }
do
  local f = io.open(racine .. "/_etiquettes.json", "r")
  if f then
    index = pandoc.json.decode(f:read("a"), false)
    f:close()
  else
    avertir("_etiquettes.json absent : lancer _outils/pre-rendu.py")
  end
end

-- Fichier en cours (rendu HTML d'un chapitre)
local fichier_courant, html_courant, chapitre_courant
if quarto and quarto.doc and quarto.doc.input_file then
  local f = quarto.doc.input_file
  local rel = f:sub(#racine + 2)
  fichier_courant = rel
  local info = index.fichiers[rel]
  if info then
    html_courant = info.html
    chapitre_courant = info.chapitre
    if chapitre_courant == pandoc.json.null then chapitre_courant = nil end
  end
end

-- ── Utilitaires ─────────────────────────────────────────────────────────
local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function latex(blocs)
  return trim(pandoc.write(pandoc.Pandoc(blocs), "latex"))
end

local function latex_inlines(inl)
  return latex({ pandoc.Plain(inl) })
end

local FILTRE_INLINES -- défini plus bas : appliqué aux textes des attributs

local function md(texte)
  if not texte or texte == "" then return pandoc.Inlines({}) end
  local d = pandoc.read(texte, "markdown")
  local inl = pandoc.utils.blocks_to_inlines(d.blocks)
  if FILTRE_INLINES then
    inl = pandoc.Inlines(inl):walk(FILTRE_INLINES)
  end
  return inl
end

local function a_classe(el, c)
  return el.classes and el.classes:includes(c)
end

local function premier_paragraphe(blocs)
  local b = blocs[1]
  if b and (b.t == "Para" or b.t == "Plain") then return b end
end

-- Insère du LaTeX brut au début du premier paragraphe (même ligne que le
-- texte, comme dans la source LaTeX d'origine), sinon en bloc séparé.
local function prefixer(blocs, tex)
  local p = premier_paragraphe(blocs)
  if p then
    p.content:insert(1, pandoc.RawInline("latex", tex))
  else
    blocs:insert(1, pandoc.RawBlock("latex", tex))
  end
  return blocs
end

-- Ajoute \end{...} à la fin du dernier paragraphe (comme dans la source
-- LaTeX : le texte est suivi de \end{env} sans ligne vide, ce qui garde,
-- par exemple, le carré de fin de démonstration sur la dernière ligne).
local function suffixer(blocs, tex)
  local d = blocs[#blocs]
  if d and (d.t == "Para" or d.t == "Plain") then
    d.content:insert(pandoc.RawInline("latex", "\n" .. tex))
  else
    blocs:insert(pandoc.RawBlock("latex", tex))
  end
  return blocs
end

-- ── Nombres (siunitx \num) ───────────────────────────────────────────────
local function grouper(ch, depuis_droite, sep)
  if #ch < 5 then return ch end
  local res = {}
  if depuis_droite then
    local d = #ch % 3
    if d > 0 then table.insert(res, ch:sub(1, d)) end
    for i = d + 1, #ch, 3 do table.insert(res, ch:sub(i, i + 2)) end
  else
    for i = 1, #ch, 3 do table.insert(res, ch:sub(i, i + 2)) end
  end
  return table.concat(res, sep)
end

-- mode « math » (dans une formule) ou « texte »
local function format_num(x, mode)
  x = x:gsub("%s", "")
  local signe, mant, exp = x:match("^([%+%-]?)([%d%.]+)[eE]([%+%-]?%d+)$")
  if not mant then
    signe, mant = x:match("^([%+%-]?)([%d%.]+)$")
  end
  if not mant then return nil end
  local ent, dec = mant:match("^(%d*)%.?(%d*)$")
  local sep = mode == "math" and "\\," or "\u{202F}"
  local s = grouper(ent, true, sep)
  if dec ~= "" then
    s = s .. (mode == "math" and "{,}" or ",") .. grouper(dec, false, sep)
  end
  if signe == "-" then s = (mode == "math" and "-" or "−") .. s end
  if exp then
    exp = exp:gsub("^%+", ""):gsub("^(%-?)0+(%d)", "%1%2")
    s = s .. " \\times 10^{" .. exp .. "}"
  end
  return s, exp ~= nil
end

local function math_web(t)
  t = t:gsub("\\num(%b{})", function(a)
    return format_num(a:sub(2, -2), "math") or a
  end)
  -- \SI{85}{\percent} (siunitx) : MathJax ne connaît que le nombre
  t = t:gsub("\\SI(%b{})(%b{})", function(a, u)
    local n = format_num(a:sub(2, -2), "math") or a:sub(2, -2)
    if u == "{\\percent}" then return n .. "\\,\\%" end
    return n .. "\\," .. u:sub(2, -2)
  end)
  -- \ang{109.47} (siunitx) : degrés
  t = t:gsub("\\ang(%b{})", function(a)
    return (format_num(a:sub(2, -2), "math") or a:sub(2, -2)) .. "^{\\circ}"
  end)
  t = t:gsub("\\qedhere", "")
  -- \ref{x} dans une formule (justification d'un align*, par exemple) :
  -- MathJax ne connaît pas les étiquettes du livre, on écrit le numéro.
  t = t:gsub("\\ref(%b{})", function(a)
    local e = index.etiquettes[a:sub(2, -2)]
    if not e then
      avertir("étiquette inconnue (formule) : " .. a:sub(2, -2))
      return "??"
    end
    return e.num
  end)
  return t
end

-- ── Siècles, renvois ─────────────────────────────────────────────────────
local function romain(n)
  local v = { { 1000, "m" }, { 900, "cm" }, { 500, "d" }, { 400, "cd" },
              { 100, "c" }, { 90, "xc" }, { 50, "l" }, { 40, "xl" },
              { 10, "x" }, { 9, "ix" }, { 5, "v" }, { 4, "iv" }, { 1, "i" } }
  local s = ""
  for _, p in ipairs(v) do
    while n >= p[1] do s = s .. p[2]; n = n - p[1] end
  end
  return s
end

local function renvoi(label, eq)
  local e = index.etiquettes[label]
  if not e then
    avertir("étiquette inconnue : " .. label)
    return pandoc.Strong(pandoc.Str("??"))
  end
  local texte = eq and ("(" .. e.num .. ")") or e.num
  if e.externe or not e.fichier then
    return pandoc.Span(pandoc.Str(texte),
      { class = "renvoi-externe",
        title = "Chapitre pas encore converti au format web" })
  end
  local cible = "#" .. label
  if e.fichier ~= html_courant then cible = e.fichier .. cible end
  return pandoc.Link(pandoc.Str(texte), cible, "", { class = "renvoi" })
end

local function defini_dans_livre(label)
  local e = index.etiquettes[label]
  return e and not e.externe
end

-- ── Vidéos (::: {.video src="https://youtu.be/…" title="…"} :::) ─────────
local function id_youtube(src)
  return src:match("youtu%.be/([%w_%-]+)") or src:match("[?&]v=([%w_%-]+)")
    or src:match("/embed/([%w_%-]+)")
end

-- ═══════════════════════════════════════════════════════════════════════
--  Passe 1 : éléments en ligne
-- ═══════════════════════════════════════════════════════════════════════
local function est_renvoi(el)
  return el and el.t == "RawInline" and el.format:match("tex")
    and el.text:match("^\\e?q?ref{")
end

local inlines_latex = {
  Inlines = function(inl)
    local res = pandoc.Inlines({})
    for i, el in ipairs(inl) do
      local suivant = inl[i + 1]
      if el.t == "Space" and (est_renvoi(suivant) or
                              (suivant and suivant.t == "Cite")) then
        -- espace insécable avant un renvoi ou une citation (~ du LaTeX)
        if est_renvoi(suivant) then res:insert(pandoc.RawInline("latex", "~"))
        elseif inl[i - 1] and inl[i - 1].t == "Note" then res:insert(el) end
      elseif el.t == "Cite" then
        local cles = {}
        local pre, post = "", ""
        for _, c in ipairs(el.citations) do
          table.insert(cles, c.id)
          if #c.prefix > 0 then pre = latex_inlines(c.prefix) end
          if #c.suffix > 0 then post = trim(latex_inlines(c.suffix):gsub("^,", "")) end
        end
        local opt = ""
        if pre ~= "" then opt = "[" .. pre .. "][" .. post .. "]"
        elseif post ~= "" then opt = "[" .. post .. "]" end
        -- espace insécable avant la citation, sauf après une note de bas
        -- de page (l'ancien source y mettait une espace ordinaire)
        local tilde = (inl[i - 1] and inl[i - 1].t == "Space"
                       and not (inl[i - 2] and inl[i - 2].t == "Note")) and "~" or ""
        res:insert(pandoc.RawInline("latex",
          tilde .. "\\cite" .. opt .. "{" .. table.concat(cles, ",") .. "}"))
      elseif el.t == "RawInline" and el.format:match("tex") then
        -- renvoi vers un chapitre pas encore converti : numéro en clair
        local lab = el.text:match("^\\ref{([^}]*)}$")
        local labeq = el.text:match("^\\eqref{([^}]*)}$")
        local l = lab or labeq
        if l and not defini_dans_livre(l) and index.etiquettes[l] then
          local n = index.etiquettes[l].num
          res:insert(pandoc.Str(labeq and ("(" .. n .. ")") or n))
        else
          res:insert(el)
        end
      else
        res:insert(el)
      end
    end
    return res
  end,
  Span = function(s)
    if a_classe(s, "defi") then
      local c = pandoc.Inlines({ pandoc.RawInline("latex", "\\defi{") })
      c:extend(s.content)
      c:insert(pandoc.RawInline("latex", "}"))
      return c
    end
  end,
}

-- espace fine insécable à l'intérieur des guillemets et avant « ; ! ? »,
-- espace insécable ordinaire avant le deux-points
local GUILLEMETS_FERMANTS = { ["»"] = "\u{202F}", [":"] = "\u{A0}",
                              [";"] = "\u{202F}", ["!"] = "\u{202F}",
                              ["?"] = "\u{202F}" }

local function brut_web(el)
  local t = el.text
  local lab = t:match("^\\ref{([^}]*)}$")
  if lab then return renvoi(lab, false) end
  lab = t:match("^\\eqref{([^}]*)}$")
  if lab then return renvoi(lab, true) end
  local n = t:match("^\\num{([^}]*)}$")
  if n then
    local s, exp = format_num(n, "texte")
    if not s then return pandoc.Str(n) end
    if exp then return pandoc.Math("InlineMath", format_num(n, "math")) end
    return pandoc.Str(s)
  end
  n = t:match("^\\siecle{(%d+)}$")
  if n then
    return pandoc.Inlines({ pandoc.SmallCaps(pandoc.Str(romain(tonumber(n)))),
      pandoc.Superscript(pandoc.Str("e")), pandoc.Str("\u{A0}siècle") })
  end
  if t:match("^\\LaTeX") then return pandoc.Str("LaTeX") end
  if t:match("^\\hfill") then return pandoc.Space() end
  n = t:match("^\\ap{([^}]*)}$")
  if n then return pandoc.Superscript(pandoc.Str(n)) end
  if t:match("^\\begin{") then
    return pandoc.Math("DisplayMath", math_web(t))
  end
  avertir("LaTeX ignoré dans la version web : " .. t)
  return pandoc.Inlines({})
end

local inlines_html = {
  Inlines = function(inl)
    local res = pandoc.Inlines({})
    for i, el in ipairs(inl) do
      local suivant = inl[i + 1]
      local prec = inl[i - 1]
      if el.t == "Space" and (est_renvoi(suivant) or
                              (suivant and suivant.t == "Cite")) then
        res:insert(pandoc.Str("\u{A0}"))
      elseif el.t == "Space" and suivant and suivant.t == "Str"
             and GUILLEMETS_FERMANTS[pandoc.text.sub(suivant.text, 1, 1)] then
        res:insert(pandoc.Str(GUILLEMETS_FERMANTS[pandoc.text.sub(suivant.text, 1, 1)]))
      elseif el.t == "Space" and prec and prec.t == "Str"
             and prec.text:match("«$") then
        res:insert(pandoc.Str("\u{202F}"))
      elseif el.t == "RawInline" and el.format:match("tex") then
        local r = brut_web(el)
        if r.t then res:insert(r) else res:extend(r) end
      else
        res:insert(el)
      end
    end
    -- formule en ligne et ponctuation collée (« $x$, ») : insécables, pour
    -- qu'une virgule ne commence jamais une ligne
    local res2 = pandoc.Inlines({})
    local i = 1
    while i <= #res do
      local el = res[i]
      if el.t == "Math" and el.mathtype == "InlineMath" then
        local groupe = pandoc.Inlines({})
        local prec = res2[#res2]
        if prec and prec.t == "Str" and not prec.text:match("%s$") then
          groupe:insert(table.remove(res2))
        end
        groupe:insert(el)
        local suiv = res[i + 1]
        if suiv and suiv.t == "Str" then
          groupe:insert(suiv)
          i = i + 1
        end
        if #groupe > 1 then
          res2:insert(pandoc.Span(groupe, { class = "nowrap" }))
        else
          res2:insert(el)
        end
      else
        res2:insert(el)
      end
      i = i + 1
    end
    return res2
  end,
  Math = function(m)
    m.text = math_web(m.text)
    return m
  end,
  Link = function(l)
    -- lien interne vers une étiquette d'un chapitre non converti
    local lab = l.target:match("^#(.+)$")
    if lab and index.etiquettes[lab] then
      local e = index.etiquettes[lab]
      if e.externe then
        return pandoc.Span(l.content, { class = "renvoi-externe" })
      elseif e.fichier ~= html_courant then
        l.target = e.fichier .. "#" .. lab
      end
    elseif lab and lab:match(":") and not index.etiquettes[lab] then
      return pandoc.Span(l.content, { class = "renvoi-externe" })
    end
    return l
  end,
}

FILTRE_INLINES = LATEX and inlines_latex or inlines_html

-- ═══════════════════════════════════════════════════════════════════════
--  Figures
-- ═══════════════════════════════════════════════════════════════════════
local function nom_tikz(src)
  return src:match("([^/]+)%.tikz$")
end

local function image_latex(img)
  local src = img.src
  if src:match("%.tikz$") then return "\\input{" .. src .. "}" end
  local w = img.attributes["width"]
  if w and w:match("%%$") then
    local f = tonumber(w:sub(1, -2)) / 100
    return "\\includegraphics[width=" .. f .. "\\textwidth]{" .. src .. "}"
  end
  return "\\includegraphics{" .. src .. "}"
end

-- Image TikZ -> image web (SVG ou PNG) à la même échelle que dans le PDF
local function image_web(img)
  local nom = nom_tikz(img.src)
  if not nom then return img end
  local fig = index.figures[nom]
  if not fig then
    avertir("figure non compilée : " .. img.src)
    return img
  end
  img.src = fig.web
  local l = math.min(100, math.floor(fig.largeur * 1000 + 0.5) / 10)
  img.attributes["style"] = "width:" .. l .. "%"
  img.classes:insert("figure-tikz")
  return img
end

local function decomposer_figure(div)
  local img, leg = nil, pandoc.Inlines({})
  for _, b in ipairs(div.content) do
    if (b.t == "Para" or b.t == "Plain") and not img and b.content[1]
       and b.content[1].t == "Image" then
      img = b.content[1]
    elseif b.t == "Para" or b.t == "Plain" then
      if #leg > 0 then leg:insert(pandoc.Space()) end
      leg:extend(b.content)
    end
  end
  return img, leg
end

local figures_latex = {
  Div = function(d)
    if not d.identifier:match("^fig:") then return nil end
    local img, leg = decomposer_figure(d)
    if not img then return nil end
    return pandoc.RawBlock("latex",
      "\\begin{figure}[htbp]\n  \\centering\n  " .. image_latex(img) ..
      "\n  \\caption{" .. latex_inlines(leg) .. "}\n  \\label{" ..
      d.identifier .. "}\n\\end{figure}")
  end,
}

local figures_html = {
  Div = function(d)
    if not d.identifier:match("^fig:") then return nil end
    local img, leg = decomposer_figure(d)
    if not img then return nil end
    local etiq = pandoc.Span(pandoc.Str("Figure " .. (d.attributes.num or "")
      .. "\u{A0}:"), { class = "figure-etiquette" })
    local legende = pandoc.Inlines({ etiq, pandoc.Space() })
    legende:extend(leg)
    return pandoc.Div({
      pandoc.Para({ image_web(img) }),
      pandoc.Div({ pandoc.Plain(legende) }, { class = "figure-legende" }),
    }, { id = d.identifier, class = "figure-livre" })
  end,
}

-- ═══════════════════════════════════════════════════════════════════════
--  Listes (PDF) : enumerate / itemize / sousquestions de la classe
-- ═══════════════════════════════════════════════════════════════════════
local function etiquette_liste(style, delim, k)
  local v
  if style == "LowerAlpha" then v = string.char(96 + k)
  elseif style == "UpperAlpha" then v = string.char(64 + k)
  elseif style == "LowerRoman" then v = romain(k)
  elseif style == "UpperRoman" then v = romain(k):upper()
  else v = tostring(k) end
  if delim == "TwoParens" then return "(" .. v .. ")"
  elseif delim == "OneParen" then return v .. ")"
  else return v .. "." end
end

local function liste_latex(el, prof)
  local debut, fin, explicite = "\\begin{itemize}", "\\end{itemize}", nil
  if el.t == "OrderedList" then
    local st = el.listAttributes.style
    local de = el.listAttributes.delimiter
    debut, fin = "\\begin{enumerate}", "\\end{enumerate}"
    local decimal = (st == "Decimal" or st == "DefaultStyle")
      and (de == "Period" or de == "DefaultDelim")
    if st == "LowerAlpha" and de == "OneParen" and prof == 1 then
      debut, fin = "\\begin{sousquestions}", "\\end{sousquestions}"
      -- Liste reprise après une interruption : « d) » plutôt que « a) »
      if el.listAttributes.start > 1 then
        debut = debut .. "\\setcounter{enumi}{"
          .. (el.listAttributes.start - 1) .. "}"
      end
    elseif (prof == 1 and decimal)
        or (prof == 2 and st == "LowerAlpha" and de == "TwoParens") then
      explicite = nil
    else
      explicite = function(k)
        return etiquette_liste(st, de, k + el.listAttributes.start - 1)
      end
    end
  end
  local res = pandoc.Blocks({ pandoc.RawBlock("latex", debut) })
  for k, item in ipairs(el.content) do
    local blocs = pandoc.Blocks({})
    for _, b in ipairs(item) do
      if b.t == "BulletList" or b.t == "OrderedList" then
        blocs:extend(liste_latex(b, prof + 1))
      else
        blocs:insert(b)
      end
    end
    local marque = "\\item" .. (explicite and ("[" .. explicite(k) .. "]") or "") .. " "
    prefixer(blocs, marque)
    res:extend(blocs)
  end
  res:insert(pandoc.RawBlock("latex", fin))
  return res
end

local listes_latex = {
  traverse = "topdown",
  BulletList = function(l) return liste_latex(l, 1), false end,
  OrderedList = function(l) return liste_latex(l, 1), false end,
}

-- Listes et paragraphes (PDF). Dans le livre, une liste est presque
-- toujours collée au texte qui la précède et à celui qui la suit (pas de
-- ligne vide autour de \begin{itemize} et \end{itemize}) : LaTeX en fait
-- un seul paragraphe, ce qui règle les espacements. Le filtre reproduit
-- cet usage ; pour séparer, mettre une ligne « \par » entre les deux.
local DEBUT_LISTE = { "^\\begin{itemize}", "^\\begin{enumerate}",
                      "^\\begin{sousquestions}" }
local FIN_LISTE = { "\\end{itemize}$", "\\end{enumerate}$",
                    "\\end{sousquestions}$" }

local function correspond(b, motifs)
  if not b or b.t ~= "RawBlock" then return false end
  for _, m in ipairs(motifs) do
    if b.text:match(m) then return true end
  end
  return false
end

local function texte(b)
  return b and (b.t == "Para" or b.t == "Plain")
    and not (#b.content == 1 and b.content[1].t == "Image")
end

local coller_listes = {
  Blocks = function(blocs)
    local res = pandoc.Blocks({})
    local i = 1
    while i <= #blocs do
      local b, s = blocs[i], blocs[i + 1]
      if texte(b) and correspond(s, DEBUT_LISTE) then
        -- texte puis \begin{liste} : même paragraphe
        b.content:insert(pandoc.RawInline("latex", "\n" .. s.text))
        res:insert(b)
        i = i + 2
      elseif correspond(b, FIN_LISTE) and texte(s) then
        -- \end{liste} puis texte : même paragraphe
        s.content:insert(1, pandoc.RawInline("latex", b.text .. "\n"))
        blocs[i + 1] = s
        i = i + 1
      else
        res:insert(b)
        i = i + 1
      end
    end
    return res
  end,
}

local listes_html = {
  OrderedList = function(l)
    local de = l.listAttributes.delimiter
    if de == "OneParen" or de == "TwoParens" then
      local c = de == "OneParen" and "liste-parenthese" or "liste-parentheses"
      -- Liste reprise après une interruption : « d) » plutôt que « a) »
      if l.listAttributes.start > 1 then
        return pandoc.Div({ l }, pandoc.Attr("", { c, "liste-debut" },
          { style = "--debut: " .. (l.listAttributes.start - 1) }))
      end
      return pandoc.Div({ l }, { class = c })
    end
  end,
}

-- ═══════════════════════════════════════════════════════════════════════
--  Environnements, tableaux, code (PDF)
-- ═══════════════════════════════════════════════════════════════════════
local ALIGN = { AlignLeft = "l", AlignCenter = "c", AlignRight = "r",
                AlignDefault = "l" }

local function cellules(rangee)
  local t = {}
  for _, c in ipairs(rangee.cells) do
    table.insert(t, latex(c.contents))
  end
  return table.concat(t, " & ") .. " \\\\"
end

-- Le tabular d'un tableau. `colonnes` (attribut du div englobant) donne la
-- spécification LaTeX quand le Markdown ne suffit pas (colonnes p{..},
-- filet vertical) ; `espacement` est ajouté après chaque rangée du corps
-- (\\[10pt]), pour les tableaux de matrices.
local function tabular_latex(tab, colonnes, espacement)
  local spec = colonnes
  if not spec then
    spec = ""
    for _, cs in ipairs(tab.colspecs) do spec = spec .. ALIGN[cs[1]] end
  end
  local l = { "\\begin{tabular}{@{}" .. spec .. "@{}}", "\\toprule" }
  for _, r in ipairs(tab.head.rows) do table.insert(l, cellules(r)) end
  table.insert(l, "\\midrule")
  local rangees = {}
  for _, corps in ipairs(tab.bodies) do
    for _, r in ipairs(corps.body) do table.insert(rangees, cellules(r)) end
  end
  for k, r in ipairs(rangees) do
    if espacement and k < #rangees then r = r .. "[" .. espacement .. "]" end
    table.insert(l, r)
  end
  table.insert(l, "\\bottomrule")
  table.insert(l, "\\end{tabular}")
  return table.concat(l, "\n")
end

local function tableau_latex(tab)
  return pandoc.RawBlock("latex", "\\begin{center}\n" .. tabular_latex(tab)
    .. "\n\\end{center}")
end

-- Div #tab:x (table numérotée, légende au-dessus) ou .tableau (réglages
-- seulement) : la légende est le texte qui précède le tableau.
local function decomposer_tableau(div)
  local tab, leg = nil, pandoc.Inlines({})
  for _, b in ipairs(div.content) do
    if b.t == "Table" and not tab then
      tab = b
    elseif (b.t == "Para" or b.t == "Plain") and not tab then
      if #leg > 0 then leg:insert(pandoc.Space()) end
      leg:extend(b.content)
    end
  end
  return tab, leg
end

local function est_div_tableau(d)
  return d.identifier:match("^tab:") or a_classe(d, "tableau")
end

local tableaux_latex = {
  Div = function(d)
    if not est_div_tableau(d) then return nil end
    local tab, leg = decomposer_tableau(d)
    if not tab then return nil end
    local t = tabular_latex(tab, d.attributes.colonnes, d.attributes.espacement)
    if d.identifier:match("^tab:") then
      -- Trois blocs : Quarto avertit (« Raw LaTeX table found with non-tbl
      -- label ») s'il trouve \label et \begin{table} dans le même bloc.
      return {
        pandoc.RawBlock("latex", "\\begin{table}[htbp]\n  \\centering\n  \\caption{"
          .. latex_inlines(leg) .. "}"),
        pandoc.RawBlock("latex", "  \\label{" .. d.identifier .. "}"),
        pandoc.RawBlock("latex", "  \\small\n" .. t .. "\n\\end{table}"),
      }
    end
    return pandoc.RawBlock("latex", "\\begin{center}\n" .. t .. "\n\\end{center}")
  end,
}

local tableaux_html = {
  Div = function(d)
    if not est_div_tableau(d) then return nil end
    local tab, leg = decomposer_tableau(d)
    if not tab then return nil end
    if not d.identifier:match("^tab:") then return tab end
    local etiq = pandoc.Span(pandoc.Str("Table " .. (d.attributes.num or "")
      .. "\u{A0}:"), { class = "figure-etiquette" })
    local legende = pandoc.Inlines({ etiq, pandoc.Space() })
    legende:extend(leg)
    return pandoc.Div({
      pandoc.Div({ pandoc.Plain(legende) }, { class = "figure-legende tableau-legende" }),
      tab,
    }, { id = d.identifier, class = "table-livre" })
  end,
}

local STYLES_CODE = { python = "stylePy", r = "styleR" }

local function code_latex(cb)
  for _, c in ipairs(cb.classes) do
    if c:match("ojs") then return {} end
  end
  local langue = cb.classes[1]
  local opts = { "style=" .. (STYLES_CODE[langue] or "styleJSbase") }
  local cap = cb.attributes["caption"]
  if cap then table.insert(opts, "caption={" .. latex_inlines(md(cap)) .. "}") end
  if cb.identifier ~= "" then table.insert(opts, "label={" .. cb.identifier .. "}") end
  return pandoc.RawBlock("latex", "\\begin{lstlisting}[" ..
    table.concat(opts, ", ") .. "]\n" .. cb.text .. "\n\\end{lstlisting}")
end

-- Portrait (ou figure TikZ) et texte côte à côte, dans un tabular comme
-- dans l'ancien source. position="droite" : texte à gauche, image à
-- droite ; largeur : fraction de la ligne occupée par l'image (0.24).
local function portrait_latex(d)
  local leg = latex_inlines(md(d.attributes.legende))
  local credit = latex_inlines(md(d.attributes.credit))
  local src = d.attributes.src
  local l = tonumber(d.attributes.largeur or "0.24")
  local image
  if src:match("%.tikz$") then
    image = "\\input{" .. src .. "}"
  else
    image = "\\includegraphics[width=\\linewidth]{" .. src .. "}"
  end
  if leg ~= "" or credit ~= "" then
    image = image .. "\\\\[3pt]\n{\\scriptsize " .. leg ..
      (credit ~= "" and ("\\\\\n " .. credit) or "") .. "\\par}"
  end
  local cellule_image = "\\vspace{0pt}\n\\centering\n" .. image
  local cellule_texte = "\\vspace{0pt}\n" .. latex(d.content)
  local col_image = "p{" .. l .. "\\linewidth}"
  local col_texte = "p{" .. (0.97 - l) .. "\\linewidth}"
  local sep = "@{\\hspace{0.03\\linewidth}}"
  if d.attributes.position == "droite" then
    return pandoc.RawBlock("latex",
      "\\noindent\\begin{tabular}{@{}" .. col_texte .. sep .. col_image .. "@{}}\n" ..
      cellule_texte .. "\n&\n" .. cellule_image .. "\n\\end{tabular}")
  end
  return pandoc.RawBlock("latex",
    "\\noindent\\begin{tabular}{@{}" .. col_image .. sep .. col_texte .. "@{}}\n" ..
    cellule_image .. "\n&\n" .. cellule_texte .. "\n\\end{tabular}")
end

local blocs_latex = {
  Para = function(p)
    -- image TikZ seule, hors figure : centrée
    if #p.content == 1 and p.content[1].t == "Image" then
      return pandoc.RawBlock("latex", "\\begin{center}\n" ..
        image_latex(p.content[1]) .. "\n\\end{center}")
    end
  end,
  Table = tableau_latex,
  CodeBlock = code_latex,
  Div = function(d)
    local env = numerotation.classe_env(d)
    local id = d.identifier
    local lab = id ~= "" and ("\\label{" .. id .. "}") or ""
    local blocs = d.content
    if env == "exercice" then
      local o = a_classe(d, "python") and "[python]"
        or (a_classe(d, "classe") and "[classe]" or "")
      prefixer(blocs, "\\begin{exercice}" .. o .. lab)
      suffixer(blocs, "\\end{exercice}")
      return blocs
    elseif env then
      local titre = latex_inlines(md(d.attributes.title))
      prefixer(blocs, "\\begin{" .. env .. "}{" .. titre .. "}" .. lab)
      suffixer(blocs, "\\end{" .. env .. "}")
      if d.attributes.needspace then
        blocs:insert(1, pandoc.RawBlock("latex",
          "\\Needspace{" .. d.attributes.needspace .. "\\baselineskip}"))
      end
      return blocs
    elseif a_classe(d, "solution") then
      -- écrite telle quelle dans sol-chN.tex par le paquet answers :
      -- aucune ligne vide après \begin{solution}
      return pandoc.RawBlock("latex", "\\begin{solution}\n" ..
        latex(blocs) .. "\n\\end{solution}")
    elseif a_classe(d, "demonstration") then
      -- démonstration hors environnement proof (chapitre 1) : mêmes
      -- commandes que l'ancien source
      prefixer(blocs, "\\DebutDemonstration ")
      suffixer(blocs, "\\FinDemonstration")
      return blocs
    elseif a_classe(d, "proof") or a_classe(d, "extrait") then
      local nom = a_classe(d, "proof") and "proof" or "extrait"
      -- titre facultatif : ::: {.proof title="Démonstration du théorème..."}
      local opt = ""
      if nom == "proof" and d.attributes.title then
        opt = "[" .. latex_inlines(md(d.attributes.title)) .. "]"
      end
      prefixer(blocs, "\\begin{" .. nom .. "}" .. opt)
      suffixer(blocs, "\\end{" .. nom .. "}")
      return blocs
    elseif a_classe(d, "video") then
      local titre = latex_inlines(md(d.attributes.title or "Voir la vidéo"))
      return pandoc.RawBlock("latex", "\\par\\noindent{\\color{firebrick3}\\faYoutube}\\enspace"
        .. "\\href{" .. d.attributes.src .. "}{" .. titre .. "}\\par")
    elseif a_classe(d, "portrait") then
      return portrait_latex(d)
    elseif a_classe(d, "center") then
      blocs:insert(1, pandoc.RawBlock("latex", "\\begin{center}"))
      blocs:insert(pandoc.RawBlock("latex", "\\end{center}"))
      return blocs
    end
  end,
}

-- ═══════════════════════════════════════════════════════════════════════
--  Environnements, tableaux, code (HTML)
-- ═══════════════════════════════════════════════════════════════════════
local ICONES = {
  python = '<i class="bi bi-laptop" aria-hidden="true"></i>',
  classe = '<i class="bi bi-easel" aria-hidden="true"></i>',
}

local function icone(nom)
  return pandoc.RawInline("html", ICONES[nom] .. " ")
end

local function env_html(d, env)
  local num = d.attributes.num or ""
  local etiq = pandoc.Inlines({})
  if env == "secondaire" then etiq:insert(icone("classe")) end
  if env == "outil" then etiq:insert(icone("python")) end
  etiq:insert(pandoc.Str(numerotation.nom[env] .. "\u{A0}" .. num))
  local entete = pandoc.Inlines({
    pandoc.Span(etiq, { class = "env-etiquette" }),
    pandoc.Span(md(d.attributes.title), { class = "env-titre" }) })
  local classes = { "env", "env-" .. env }
  return pandoc.Div({
    pandoc.Div({ pandoc.Plain(entete) }, { class = "env-entete" }),
    pandoc.Div(d.content, { class = "env-corps" }),
  }, { id = d.identifier, class = table.concat(classes, " ") })
end

local function exercice_html(d)
  local type = a_classe(d, "python") and "python"
    or (a_classe(d, "classe") and "classe" or nil)
  local etiq = pandoc.Inlines({})
  if type then etiq:insert(icone(type)) end
  etiq:insert(pandoc.Str("Exercice\u{A0}" .. (d.attributes.num or "") .. "."))
  local span = pandoc.Span(etiq, { class = "exo-etiquette" })
  local blocs = d.content
  local p = premier_paragraphe(blocs)
  if p then
    p.content:insert(1, pandoc.Space())
    p.content:insert(1, span)
  else
    blocs:insert(1, pandoc.Plain({ span }))
  end
  return pandoc.Div(blocs, { id = d.identifier,
    class = "exercice" .. (type and (" exercice-" .. type) or "") })
end

local function preuve_html(d)
  local blocs = d.content
  local p = premier_paragraphe(blocs)
  local debut = pandoc.Emph(pandoc.Str("Démonstration."))
  if d.attributes.title then
    local titre = md(d.attributes.title)
    titre:insert(pandoc.Str("."))
    debut = pandoc.Emph(titre)
  end
  if p then
    p.content:insert(1, pandoc.Space())
    p.content:insert(1, debut)
  else
    blocs:insert(1, pandoc.Plain({ debut }))
  end
  local dernier = blocs[#blocs]
  local qed = pandoc.Span(pandoc.Str("∎"), { class = "qed" })
  if dernier and (dernier.t == "Para" or dernier.t == "Plain") then
    dernier.content:insert(qed)
  else
    blocs:insert(pandoc.Plain({ qed }))
  end
  return pandoc.Div(blocs, { class = "preuve" })
end

local function portrait_html(d)
  local leg = md(d.attributes.legende)
  local credit = md(d.attributes.credit)
  if #credit > 0 then
    leg:insert(pandoc.LineBreak())
    leg:extend(credit)
  end
  local img = pandoc.Image({}, d.attributes.src, "", { class = "portrait-photo" })
  if nom_tikz(d.attributes.src) then
    img = image_web(img)
    img.attributes["style"] = nil
  end
  local cellule = { pandoc.Para({ img }) }
  if #leg > 0 then
    table.insert(cellule, pandoc.Div({ pandoc.Plain(leg) }, { class = "portrait-legende" }))
  end
  local image = pandoc.Div(cellule, { class = "portrait-image" })
  local texte = pandoc.Div(d.content, { class = "portrait-texte" })
  if d.attributes.position == "droite" then
    return pandoc.Div({ texte, image }, { class = "portrait portrait-droite" })
  end
  return pandoc.Div({ image, texte }, { class = "portrait" })
end

local function code_html(cb)
  local cap = cb.attributes["caption"]
  if not cap then return nil end
  local num = cb.attributes["num"] or ""
  cb.attributes["caption"] = nil
  cb.attributes["num"] = nil
  local leg = pandoc.Inlines({ pandoc.Span(pandoc.Str("Programme\u{A0}" .. num .. "\u{A0}:"),
    { class = "listing-etiquette" }), pandoc.Space() })
  leg:extend(md(cap))
  local classes = "listing" .. (cb.classes[1] == "python" and " listing-python" or "")
  local id = cb.identifier
  cb.identifier = ""
  return pandoc.Div({ pandoc.Div({ pandoc.Plain(leg) }, { class = "listing-legende" }), cb },
                    { id = id, class = classes })
end

local blocs_html = {
  Para = function(p)
    if #p.content == 1 and p.content[1].t == "Image" and nom_tikz(p.content[1].src) then
      return pandoc.Div({ pandoc.Para({ image_web(p.content[1]) }) },
                        { class = "figure-livre figure-sans-legende" })
    end
  end,
  RawBlock = function(r)
    if r.format:match("tex") then
      if r.text:match("^\\begin{") then
        return pandoc.Para({ pandoc.Math("DisplayMath", math_web(r.text)) })
      end
      if not r.text:match("^\\[a-z]*skip$") and not r.text:match("^\\vspace")
         and r.text ~= "\\par" then
        avertir("bloc LaTeX ignoré dans la version web : " .. r.text:sub(1, 60))
      end
      return {}
    end
  end,
  Table = function(t)
    t.classes:insert("tableau-livre")
    local cs = pandoc.List()
    for _, c in ipairs(t.colspecs) do cs:insert({ c[1] }) end
    t.colspecs = cs
    return t
  end,
  CodeBlock = code_html,
  Header = function(h)
    h.attributes["num"] = nil
    return h
  end,
  Div = function(d)
    local env = numerotation.classe_env(d)
    if env == "exercice" then return exercice_html(d)
    elseif env then return env_html(d, env)
    elseif a_classe(d, "solution") then
      local blocs = pandoc.Blocks({ pandoc.RawBlock("html",
        '<details class="solution-details"><summary>Solution</summary>') })
      blocs:extend(d.content)
      blocs:insert(pandoc.RawBlock("html", "</details>"))
      return pandoc.Div(blocs, { class = "solution-bloc" })
    elseif a_classe(d, "proof") or a_classe(d, "demonstration") then
      return preuve_html(d)
    elseif a_classe(d, "extrait") then
      return pandoc.Div(d.content, { class = "extrait-citation" })
    elseif a_classe(d, "video") then
      local id = id_youtube(d.attributes.src or "")
      if not id then
        avertir("vidéo non reconnue : " .. (d.attributes.src or ""))
        return {}
      end
      local titre = (d.attributes.title or "Vidéo"):gsub('"', "&quot;")
      return pandoc.RawBlock("html",
        '<div class="video-livre ratio ratio-16x9"><iframe src="https://www.youtube.com/embed/'
        .. id .. '" title="' .. titre .. '" frameborder="0" loading="lazy" '
        .. 'allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" '
        .. 'referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe></div>')
    elseif a_classe(d, "portrait") then return portrait_html(d)
    end
  end,
}

-- ═══════════════════════════════════════════════════════════════════════
--  Structure du livre (passe finale, sur la suite des blocs du document)
-- ═══════════════════════════════════════════════════════════════════════
local function chapitres_numerotes()
  local l = {}
  for f, info in pairs(index.fichiers) do
    if info.chapitre and info.chapitre ~= pandoc.json.null then
      local titre = ""
      for _, e in pairs(index.etiquettes) do
        if e.type == "chapitre" and e.fichier == info.html then titre = e.titre end
      end
      local annexe = info.annexe == true
      table.insert(l, { num = info.chapitre, titre = titre, html = info.html,
        annexe = annexe, nom = annexe and "Annexe" or "Chapitre" })
    end
  end
  -- chapitres (1, 2, ...) puis annexes (A, B, ...)
  table.sort(l, function(a, b)
    if a.annexe ~= b.annexe then return b.annexe end
    if a.annexe then return a.num < b.num end
    return tonumber(a.num) < tonumber(b.num)
  end)
  return l
end

local function structure_latex(doc)
  local res = pandoc.Blocks({})
  local exercices_ouverts = false
  local titre_credits = "À propos de ce document"
  local blocs = doc.blocks
  local function fermer()
    if exercices_ouverts then
      res:insert(pandoc.RawBlock("latex", "\\finExercices"))
      exercices_ouverts = false
    end
  end
  for i, b in ipairs(blocs) do
    local suivant = blocs[i + 1]
    if b.t == "Header" and b.level == 1 then
      fermer()
      if a_classe(b, "avant-propos") then
        titre_credits = latex_inlines(b.content)
      elseif suivant and suivant.t == "Div" and suivant.identifier == "refs" then
        -- la bibliographie produit son propre titre (heading=bibintoc)
      elseif a_classe(b, "unnumbered") then
        local t = latex_inlines(b.content)
        res:insert(pandoc.RawBlock("latex", "\\chapter*{" .. t ..
          "}\n\\addcontentsline{toc}{chapter}{" .. t .. "}\n\\markboth{" .. t .. "}{}"))
      elseif a_classe(b, "exercices") then
        -- chapitre entièrement consacré aux exercices (séries 1 et 2)
        res:insert(b)
        res:insert(pandoc.RawBlock("latex", "\\debutExercices"))
        exercices_ouverts = true
      else
        res:insert(b)
      end
    elseif b.t == "Header" and a_classe(b, "exercices") then
      fermer()
      res:insert(pandoc.RawBlock("latex", "\\sectionExercices"))
      exercices_ouverts = true
    elseif b.t == "Div" and a_classe(b, "credits") then
      res:insert(pandoc.RawBlock("latex",
        "\\pagecouverture\n\n\\pagecredits[" .. titre_credits .. "]{%\n" ..
        latex(b.content) .. "}\n\n\\tableofcontents"))
    elseif b.t == "Div" and a_classe(b, "solutions-livre") then
      local l = {}
      for _, c in ipairs(chapitres_numerotes()) do
        table.insert(l, "\\solutionsChapitre[" .. c.nom .. "]{" .. c.num .. "}{"
          .. c.titre .. "}")
      end
      res:insert(pandoc.RawBlock("latex", table.concat(l, "\n\n")))
    elseif b.t == "Div" and b.identifier == "refs" then
      res:insert(pandoc.RawBlock("latex", "\\printbibliography[heading=bibintoc]"))
    else
      res:insert(b)
    end
  end
  fermer()
  doc.blocks = res
  return doc
end

local function macros_mathjax()
  local f = io.open(racine .. "/latex/macros-mathjax.tex", "r")
  if not f then return nil end
  local l = {}
  for ligne in f:lines() do
    ligne = ligne:gsub("%%.*$", "")
    if ligne:match("%S") then table.insert(l, ligne) end
  end
  f:close()
  local tex = table.concat(l, "\n"):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return pandoc.RawBlock("html",
    '<div class="hidden macros-mathjax">\\[' .. tex .. '\\]</div>')
end

-- Espaces insécables (web) : on enveloppe chacune dans un <span> dont le
-- style (livrejs.scss) fixe la police et la largeur, pour qu'elle soit la
-- même dans le texte, les titres en Fira Sans, le gras et l'italique :
-- espace ordinaire pour .esp-ins (U+00A0), espace fine pour .esp-fine
-- (U+202F).
local espaces_html = {
  Str = function(s)
    if not s.text:find("[\u{A0}\u{202F}]") then return nil end
    local res = pandoc.Inlines({})
    local debut = 1
    for pos, c in utf8.codes(s.text) do
      if c == 0xA0 or c == 0x202F then
        if pos > debut then res:insert(pandoc.Str(s.text:sub(debut, pos - 1))) end
        res:insert(pandoc.Span(pandoc.Str("\u{A0}"),
          { class = c == 0xA0 and "esp-ins" or "esp-fine" }))
        debut = pos + #utf8.char(c)
      end
    end
    if debut <= #s.text then res:insert(pandoc.Str(s.text:sub(debut))) end
    return res
  end,
}

local function structure_html(doc)
  local res = pandoc.Blocks({})
  -- Macros en tête du <body> : MathJax traite la page dans l'ordre, et la
  -- table des matières (barre de gauche) précède le contenu.
  local m = macros_mathjax()
  if m then
    local avant = doc.meta["include-before"] or pandoc.List({})
    if avant.t ~= "MetaList" and pandoc.utils.type(avant) ~= "List" then
      avant = pandoc.List({ avant })
    end
    table.insert(avant, 1, pandoc.MetaBlocks({ m }))
    doc.meta["include-before"] = avant
  end
  local blocs = doc.blocks
  local i = 1
  while i <= #blocs do
    local b = blocs[i]
    local suivant = blocs[i + 1]
    -- \paragraph : titre en ligne, au début du paragraphe suivant
    if b.t == "Header" and b.level >= 5 and suivant and suivant.t == "Para" then
      suivant.content:insert(1, pandoc.Space())
      suivant.content:insert(1, pandoc.Span(b.content,
        { id = b.identifier, class = "paragraphe-titre" }))
      res:insert(suivant)
      i = i + 2
    elseif b.t == "Div" and a_classe(b, "credits") then
      res:extend(b.content)
      i = i + 1
    elseif b.t == "Div" and a_classe(b, "solutions-livre") then
      res:insert(pandoc.Para({ pandoc.Str(
        "Dans la version web, chaque solution se trouve sous son exercice : il suffit de cliquer sur «\u{202F}Solution\u{202F}». Les exercices de chaque chapitre\u{A0}:") }))
      local items = {}
      for _, c in ipairs(chapitres_numerotes()) do
        local liens = pandoc.Inlines({})
        local exos = {}
        for lab, e in pairs(index.etiquettes) do
          if e.type == "exercice" and e.fichier == c.html then
            table.insert(exos, { lab = lab, num = e.num })
          end
        end
        table.sort(exos, function(a, b)
          return tonumber(a.num:match("%.(%d+)$")) < tonumber(b.num:match("%.(%d+)$"))
        end)
        for k, e in ipairs(exos) do
          if k > 1 then liens:insert(pandoc.Str(", ")) end
          liens:insert(pandoc.Link(pandoc.Str(e.num), c.html .. "#" .. e.lab))
        end
        if #exos > 0 then
          local t = pandoc.Inlines({ pandoc.Str(c.nom .. " " .. c.num .. " — " .. c.titre .. " : ") })
          t:extend(liens)
          table.insert(items, { pandoc.Plain(t) })
        end
      end
      if #items > 0 then res:insert(pandoc.BulletList(items)) end
      i = i + 1
    else
      res:insert(b)
      i = i + 1
    end
  end
  doc.blocks = res
  return doc
end

-- ═══════════════════════════════════════════════════════════════════════
--  Enchaînement des passes
-- ═══════════════════════════════════════════════════════════════════════
if LATEX then
  return {
    inlines_latex,
    figures_latex,
    tableaux_latex,
    listes_latex,
    coller_listes,
    blocs_latex,
    { Pandoc = structure_latex },
  }
elseif HTML then
  return {
    { Pandoc = function(doc)
        local d = numerotation.numeroter(doc, chapitre_courant, true)
        return d
      end },
    inlines_html,
    figures_html,
    tableaux_html,
    listes_html,
    blocs_html,
    { Pandoc = structure_html },
    espaces_html,
  }
end
return {}
