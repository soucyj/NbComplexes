# Introduction aux nombres complexes et polynômes (source Quarto)

Une seule source (`*.qmd`), deux sorties :

| Commande | Résultat |
|---|---|
| `quarto render` | le site web **et** le PDF dans `_book/` (à utiliser avant de publier : la couverture du site télécharge le PDF) |
| `quarto render --to pdf` | `_book/Introduction-nombres-complexes.pdf`, mis en page par `latex/livrejs.cls` |
| `quarto render --to html` | le site web seul dans `_book/` (vide le dossier, donc efface le PDF) |
| `quarto preview` | aperçu web qui se met à jour à chaque enregistrement |

Le PDF n'est pas une imitation de la maquette : le filtre traduit le Markdown
en environnements de `livrejs.cls`, et c'est LaTeX qui compose le livre.

## Écrire un chapitre

Un fichier par chapitre (`02-definition.qmd`), déclaré dans `_quarto.yml`
sous `chapters:` ; les annexes (par exemple `solutions.qmd`) sont déclarées sous
`appendices:` et numérotées A, B, C, D, E (`\appendix` dans le PDF).

| LaTeX (ancien `Livre.tex`) | Markdown (`.qmd`) |
|---|---|
| `\chapter{…}\label{chap:x}` | `# … {#chap:x}` |
| `\section{…}\label{sec:x}` / `\subsection` / `\paragraph` | `## … {#sec:x}` / `###` / `#####` |
| `\begin{definition}{Titre}\label{def:x}` | `::: {.definition #def:x title="Titre"}` … `:::` |
| idem `theorem`, `proposition`, `lemma`, `corollary`, `example`, `remark`, `algorithme`, `secondaire`, `outil`, `historical` | même nom de classe |
| `\Needspace{18\baselineskip}` avant une note | attribut `needspace="18"` |
| `\begin{proof}`, `\begin{extrait}` | `::: proof`, `::: extrait` |
| `\begin{exercice}[python]\label{exo:x}` | `:::: {.exercice .python #exo:x}` (ou `.classe`) |
| `\begin{solution}` (dans l'exercice) | `::: solution` |
| `\begin{sousquestions}` | liste `a)`, `b)`… |
| `\item[(i)]` | liste `(i)`, `(ii)`… |
| figure TikZ | `::: {#fig:x}` + `![](figures/tikz/x.tikz)` + légende, puis `:::` |
| `\begin{table}` + `\caption` + `\label{tab:x}` | `::: {#tab:x}` + légende + tableau Markdown, puis `:::` |
| colonnes `p{..}`, filet `\|`, rangées `\\[10pt]` | attributs `colonnes="p{2.5cm}p{9.4cm}"`, `espacement="10pt"` du div (`.tableau` si pas de légende) |
| `\DebutDemonstration` … `\FinDemonstration` | `:::: demonstration` … `::::` |
| portrait (tabular image + texte) | `::: {.portrait src=… legende=… credit=…}` ; image à droite : `position="droite" largeur="0.25"` (accepte une figure `.tikz`) |
| listing numéroté (`label=lst:x`) | ```` ```{.python #lst:x caption="…"} ```` |
| `\emph{…}`, `\textbf{…}`, `\defi{…}` | `*…*`, `**…**`, `[…]{.defi}` |
| `~\cite{a,b}` | `[@a; @b]` |
| `\ref{x}`, `\eqref{x}`, `\num{…}`, `\SI{…}{\percent}`, `\ang{…}`, `\siecle{19}` | inchangés (le filtre les traduit pour le web) |
| `\[ … \]`, `\begin{align*}` | `$$ … $$`, `\begin{align*}` inchangé |
| `lstlisting` (style Python, légende) | ```` ```{.python caption="…"} ```` |

| vidéo YouTube (solution) | `::: {.video src="https://youtu.be/…" title="…"}` puis `:::` (lecteur intégré sur le web, lien dans le PDF) |
| chapitre entier d'exercices | `# Exercices — série 1 {#chap:serie1 .exercices}` (pas de section « Exercices ») |
| équation repérée par une étoile | `\tag{$\star$}` dans un `align*` ou un `$$ … $$` |

Règles utiles :

* Une liste est collée au texte qui l'entoure, comme dans l'ancien source
  (pas de `\par` entre les deux). Pour un vrai nouveau paragraphe, mettre une
  ligne `\par` entre la liste et le texte.
* « a) » en début de paragraphe s'écrit `a\)` (sinon Markdown y voit une liste).
* Dans une solution, les réponses aux sous-questions forment une liste
  `a)`, `b)`… (une par ligne, suites de ligne en retrait de trois espaces),
  précédée d'une ligne vide si un texte l'introduit ; jamais `a\)`.
* Une nouvelle macro mathématique va dans `latex/macros-livre.tex` (PDF)
  **et** dans `latex/macros-mathjax.tex` (web).
* Contenu web seulement (figure interactive) :
  `:::: {.content-visible when-format="html"}` … `::::`
  (aucun pour l'instant dans ce volume).

## Organisation

| Dossier / fichier | Rôle |
|---|---|
| `_filtres/livrejs.lua` | Filtre principal : Markdown → LaTeX de la classe (PDF) ou HTML stylé (web) |
| `_filtres/numerotation.lua` | Numérotation calquée sur les compteurs de la classe (web) |
| `_outils/pre-rendu.py` | Avant chaque rendu : index des étiquettes, bibliographie web, figures TikZ → SVG |
| `latex/` | `livrejs.cls`, `commandesJS.sty`, palette, macros, gabarit pandoc |
| `figures/tikz/` | Une figure TikZ par fichier (incluse telle quelle dans le PDF) |
| `figures/web/` | SVG/PNG générés pour le web (ne pas modifier) |
| `styles/` | Thème web (`livrejs.scss`), polices, style bibliographique |

## Particularités de ce volume

* Source d'origine : l'ancienne version Quarto du site (`../NbComplexes_old/`,
  blocs `custom-numbered-blocks`), convertie à la main. Correspondances :
  `::: Def` → `.definition`, `::: Prop` → `.proposition`, `::: Thm` →
  `.theorem`, `::: Ex` → `.example`, `::: Rem`/`Rems` → `.remark` ;
  `**Preuve.**` après `***` → `::: proof` ; `{#exr-x}` + callout
  « Solution » → `.exercice` + `.solution` ; encadrés de la marge →
  remarques ou notes de bas de page ; `\piu` → `\pi`.
* Les figures TikZ viennent de `../NbComplexes_old/images/*/*.tex` (une par
  dossier) ; elles utilisent `tkz-euclide`, chargé dans
  `latex/macros-livre.tex`. Les figures des solutions sont réduites
  (`scale=0.55`).
* Deux chapitres d'exercices (séries 1 et 2), marqués `.exercices` au
  niveau du titre de chapitre : le filtre ouvre le fichier de solutions
  (`\debutExercices`, défini dans `latex/preambule-livre.tex`) sans
  ajouter de section « Exercices ».
* Bloc `.video` ajouté au filtre (`_filtres/livrejs.lua`).
* La couverture du PDF est composée par `\pagecouverture` (motif du plan
  complexe défini dans `latex/gabarit.tex`) ; `images/couverture-web.jpg`
  est la page 1 du PDF :
  `pdftocairo -jpeg -scale-to-x 800 -scale-to-y -1 -f 1 -l 1 -singlefile _book/Introduction-nombres-complexes.pdf images/couverture-web`
* `CNAME` (domaine `complexe.mathematiques.art`) est copié dans `_book/`.
* Les solutions des exercices sont regroupées en fin de volume (PDF) et
  repliables sous chaque exercice (web).
