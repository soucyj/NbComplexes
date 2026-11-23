#!/usr/bin/env python3
"""Étape exécutée par Quarto avant chaque rendu (pre-render).

1. Index des étiquettes : numéro de chaque théorème, figure, table,
   section, exercice... de tout le livre (chapitres 1, 2... et annexes A,
   B...), dans _etiquettes.json. Le filtre s'en sert pour les renvois
   (\\ref) entre chapitres dans la version web.
2. Bibliographie web : _bibliographie-web.json (CSL-JSON) reprend
   references.bib avec les étiquettes « alphabétiques » de biblatex
   ([Koc04]), lues dans le .bbl de la dernière compilation PDF.
3. Figures TikZ : chaque figures/tikz/<nom>.tikz est compilé en document
   autonome (mêmes polices, couleurs et styles que le livre), puis converti
   en SVG dans figures/web/. Seules les figures modifiées sont recompilées.

On peut aussi le lancer à la main :  python3 _outils/pre-rendu.py
"""
import concurrent.futures as cf
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
os.chdir(RACINE)

ETIQUETTES = RACINE / "_etiquettes.json"
TIKZ = RACINE / "figures" / "tikz"
WEB = RACINE / "figures" / "web"
LATEX = RACINE / "latex"
# Au-delà de cette taille, une figure (nuage de milliers de points) est
# servie en PNG plutôt qu'en SVG.
SVG_MAX = 1_500_000
LARGEUR_TEXTE_PT = 13.5 / 2.54 * 72.27  # \textwidth de livrejs (13,5 cm)

GABARIT_FIGURE = r"""\documentclass[11pt,tikz,border=1pt]{standalone}
\usepackage{amsmath}
\usepackage{mathtools}
\usepackage{fontspec}
\usepackage[french]{babel}
\usepackage{siunitx}
\sisetup{locale = FR}
\setmainfont{TeX Gyre Termes}
\IfFontExistsTF{Fira Sans}{\setsansfont{Fira Sans}[Scale=MatchLowercase]}{}
\usepackage{unicode-math}
\IfFontExistsTF{NewCMMath-Book.otf}{\setmathfont{NewCMMath-Book}}{}
\usepackage{livrejs-couleurs}
\usepackage{commandesJS}
\let\tipaexclam\!
\renewcommand{\!}{\ifmmode\mspace{-3mu}\else\tipaexclam\fi}
\let\tipasemicolon\;
\renewcommand{\;}{\ifmmode\mspace{5mu plus 5mu}\else\tipasemicolon\fi}
\let\tipacolon\:
\renewcommand{\:}{\ifmmode\mspace{4mu plus 2mu minus 4mu}\else\tipacolon\fi}
\usepackage{pgfplots}
\usetikzlibrary{arrows.meta}
\pgfplotsset{compat=1.18}
\input{macros-livre}
\begin{document}
\input{%s}
\end{document}
"""


def log(*a):
    print("[pre-rendu]", *a, file=sys.stderr)


# ── 1. Index des étiquettes ──────────────────────────────────────────────
def liste_yml(cle):
    """Fichiers .qmd de la liste book.<cle> dans _quarto.yml."""
    fichiers = []
    dans = False
    for l in (RACINE / "_quarto.yml").read_text(encoding="utf-8").splitlines():
        if re.match(r"^\s*%s:\s*$" % cle, l):
            dans = True
            continue
        if dans:
            m = re.match(r"^\s*-\s*(?:part:\s*)?\"?([\w./-]+\.qmd)\"?\s*$", l)
            if m:
                fichiers.append(m.group(1))
            elif re.match(r"^\s*-\s*part:|^\s+chapters:|^\s*#|^\s*$", l):
                continue
            elif not l.startswith(" " * 4):
                break
    return fichiers


def chapitres():
    """Fichiers du livre dans l'ordre : chapitres, puis annexes."""
    return liste_yml("chapters") + liste_yml("appendices")


def numerote(fichier):
    """Quarto numérote tous les chapitres, sauf index.qmd et {.unnumbered}."""
    if Path(fichier).name == "index.qmd":
        return False
    texte = (RACINE / fichier).read_text(encoding="utf-8")
    m = re.search(r"^# .*$", texte, re.M)
    return bool(m) and not re.search(r"\{[^}]*(\.unnumbered|-)[ }]", m.group(0))


def numeros_chapitres():
    """Numéro de chaque fichier : 1, 2, 3... pour les chapitres, A, B, C...
    pour les annexes (comme Quarto et \\appendix), None sinon."""
    res = {}
    n = 0
    for f in liste_yml("chapters"):
        if numerote(f):
            n += 1
            res[f] = str(n)
        else:
            res[f] = None
    n = 0
    for f in liste_yml("appendices"):
        if numerote(f):
            res[f] = chr(65 + n)
            n += 1
        else:
            res[f] = None
    return res


def indexer():
    etiquettes = {}
    fichiers = {}
    numeros = numeros_chapitres()
    annexes = set(liste_yml("appendices"))
    with tempfile.TemporaryDirectory() as tmp:
        for f in chapitres():
            num = numeros[f]
            sortie = Path(tmp) / (Path(f).stem + ".json")
            cmd = ["quarto", "pandoc", f, "-f", "markdown",
                   "-L", "_filtres/indexer.lua", "-M", "sortie=%s" % sortie,
                   "-t", "json", "-o", os.devnull]
            if num:
                cmd += ["-M", "chapitre=%s" % num]
            subprocess.run(cmd, check=True)
            html = str(Path(f).with_suffix(".html"))
            fichiers[f] = {"chapitre": num, "html": html,
                           "annexe": f in annexes}
            for k, v in json.loads(sortie.read_text(encoding="utf-8")).items():
                v["fichier"] = html
                etiquettes[k] = v
    log("%d étiquettes" % len(etiquettes))
    return {"fichiers": fichiers, "etiquettes": etiquettes}


# ── 2. Bibliographie web ─────────────────────────────────────────────────
def etiquettes_bbl():
    """labelalpha + extraalpha de la compilation PDF la plus récente."""
    bbls = sorted(list(RACINE.glob("*.bbl")) + [RACINE.parent / "Livre.bbl"],
                  key=lambda p: p.stat().st_mtime if p.exists() else 0)
    res = {}
    for bbl in bbls:  # du plus ancien au plus récent : le récent l'emporte
        if not bbl.exists():
            continue
        t = bbl.read_text(encoding="utf-8", errors="replace")
        for e in re.split(r"\\entry\{", t)[1:]:
            cle = e.split("}", 1)[0]
            m = re.search(r"\\field\{labelalpha\}\{([^}]*)\}", e)
            if not m:
                continue
            res[cle] = m.group(1)
    return res


def etiquette_calculee(item):
    noms = [a.get("family", a.get("literal", "?")) for a in
            item.get("author", item.get("editor", []))] or ["?"]
    noms = [re.sub(r"^(von|van|de|der|du|la|le)\s+", "", n) for n in noms]
    if len(noms) == 1:
        e = noms[0][:3]
    elif len(noms) <= 3:
        e = "".join(n[0] for n in noms)
    else:
        e = "".join(n[0] for n in noms[:3]) + "+"
    an = str(item.get("issued", {}).get("date-parts", [[""]])[0][0])
    return e + an[-2:]


def bibliographie():
    bib = RACINE / "references.bib"
    sortie = RACINE / "_bibliographie-web.json"
    r = subprocess.run(["quarto", "pandoc", str(bib), "-f", "biblatex",
                        "-t", "csljson"], capture_output=True, text=True,
                       check=True)
    items = json.loads(r.stdout)
    bbl = etiquettes_bbl()
    for it in items:
        it["citation-label"] = bbl.get(it["id"]) or etiquette_calculee(it)
    # Lettres de désambiguïsation (extraalpha de biblatex : ORa, ORb...),
    # calculées sur les références réellement citées dans le livre, triées
    # comme biblatex (étiquette, puis auteur, année et titre).
    citees = set()
    for f in chapitres():
        citees |= set(re.findall(r"(?<![\w.])@([A-Za-z][\w:-]*)",
                                 (RACINE / f).read_text(encoding="utf-8")))
    groupes = {}
    for it in items:
        if it["id"] in citees:
            groupes.setdefault(it["citation-label"], []).append(it)
    for groupe in groupes.values():
        if len(groupe) > 1:
            groupe.sort(key=lambda it: (
                str(it.get("author", "")), str(it.get("issued", "")),
                it.get("title", "")))
            for k, it in enumerate(groupe):
                it["citation-label"] += chr(97 + k)
    sortie.write_text(json.dumps(items, ensure_ascii=False, indent=1),
                      encoding="utf-8")


# ── 3. Figures TikZ ──────────────────────────────────────────────────────
def dependances(src):
    deps = [src, LATEX / "macros-livre.tex", LATEX / "livrejs-couleurs.sty",
            LATEX / "commandesJS.sty"]
    code = src.read_text(encoding="utf-8")
    for m in re.finditer(r"\\input\{([^}]*)\}", code):
        motif = re.sub(r"\\[a-zA-Z]+", "*", m.group(1))
        deps += [Path(p) for p in glob.glob(str(RACINE / motif))]
    return deps


def largeur_pt(svg):
    with open(svg, encoding="utf-8") as f:
        tete = f.read(2000)
    m = re.search(r'width="([\d.]+)(pt)?"', tete)
    return float(m.group(1)) * (72.27 / 72) if m else None


def compiler(src):
    nom = src.stem
    svg = WEB / (nom + ".svg")
    png = WEB / (nom + ".png")
    cible = svg if svg.exists() else png
    if cible.exists():
        t = cible.stat().st_mtime
        if all(d.stat().st_mtime <= t for d in dependances(src)):
            return nom, "à jour"
    with tempfile.TemporaryDirectory() as tmp:
        tex = Path(tmp) / (nom + ".tex")
        tex.write_text(GABARIT_FIGURE % ("figures/tikz/" + nom + ".tikz"),
                       encoding="utf-8")
        env = dict(os.environ, TEXINPUTS=str(LATEX) + "//:")
        r = subprocess.run(["lualatex", "-interaction=nonstopmode",
                            "-halt-on-error", "-output-directory", tmp, str(tex)],
                           cwd=RACINE, env=env, capture_output=True, text=True)
        pdf = Path(tmp) / (nom + ".pdf")
        if r.returncode or not pdf.exists():
            erreur = [l for l in r.stdout.splitlines() if l.startswith("!")]
            return nom, "ÉCHEC : " + " / ".join(erreur[:3])
        for p in (svg, png):
            p.unlink(missing_ok=True)
        subprocess.run(["pdftocairo", "-svg", str(pdf), str(svg)], check=True)
        if svg.stat().st_size > SVG_MAX:
            svg.unlink()
            subprocess.run(["pdftocairo", "-png", "-r", "250", "-singlefile",
                            "-transp", str(pdf), str(WEB / nom)], check=True)
            return nom, "PNG"
    return nom, "SVG"


def figures():
    WEB.mkdir(parents=True, exist_ok=True)
    sources = sorted(TIKZ.glob("*.tikz"))
    echecs = []
    with cf.ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
        for nom, etat in ex.map(compiler, sources):
            if etat != "à jour":
                log("figure %-28s %s" % (nom, etat))
            if etat.startswith("ÉCHEC"):
                echecs.append(nom)
    # Sur GitHub Actions (CI=true), une figure qui ne compile pas arrête la
    # publication : sinon le site serait mis en ligne avec des images brisées.
    if echecs and os.environ.get("CI"):
        sys.exit("[pre-rendu] %d figure(s) en échec : %s"
                 % (len(echecs), ", ".join(echecs)))
    infos = {}
    for src in sources:
        svg = WEB / (src.stem + ".svg")
        png = WEB / (src.stem + ".png")
        if svg.exists():
            infos[src.stem] = {"web": str(svg.relative_to(RACINE)),
                               "largeur": largeur_pt(svg) / LARGEUR_TEXTE_PT}
        elif png.exists():
            # PNG à 250 ppp : largeur en points = pixels * 72.27 / 250
            r = subprocess.run(["file", str(png)], capture_output=True,
                               text=True).stdout
            m = re.search(r"(\d+) x \d+", r)
            l = int(m.group(1)) * 72.27 / 250 if m else LARGEUR_TEXTE_PT
            infos[src.stem] = {"web": str(png.relative_to(RACINE)),
                               "largeur": l / LARGEUR_TEXTE_PT}
    return infos


def main():
    index = indexer()
    bibliographie()
    index["figures"] = figures()
    ETIQUETTES.write_text(json.dumps(index, ensure_ascii=False, indent=1),
                          encoding="utf-8")


if __name__ == "__main__":
    main()
