% ═══════════════════════════════════════════════════════════════════════
%  livrejs.cls — Classe de livre mathématique (français, LuaLaTeX)
%  Jérôme Soucy — v1.0
%
%  Mise en page à large marge de gauche : les numéros de titres, les
%  étiquettes de théorèmes et d'exercices se logent dans la marge.
%
%  Compilation : lualatex (obligatoire — fontspec/unicode-math) + biber.
%
%  Options :
%    sanscommandes   ne charge pas commandesJS.sty (ni ses correctifs)
%    toute autre option est transmise à la classe « book »
% ═══════════════════════════════════════════════════════════════════════
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{livrejs}[2026/09/08 v1.0 Livre mathematique en francais]

\newif\ifjs@commandes \js@commandestrue
\DeclareOption{sanscommandes}{\js@commandesfalse}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{book}}
\ProcessOptions\relax

\LoadClass[11pt,a4paper,oneside,openany]{book}

% ── Maths utilitaires ───────────────────────────────────────────────
% Chargés avant fontspec/unicode-math : sinon \underbrace/\overbrace
% s'affichent comme des bandes noires.
\RequirePackage{amsmath}
\RequirePackage{mathtools}     % \coloneqq, etc.
\RequirePackage{amsthm}

% ── Encodage & langue ───────────────────────────────────────────────
\RequirePackage{fontspec}
\RequirePackage[french]{babel}

% ── Nombres (virgule décimale à la française) ────────────────────────
\RequirePackage{siunitx}
\sisetup{locale = FR}

% ── Polices ─────────────────────────────────────────────────────────
% Chaque police a une solution de repli présente dans toute TeX Live,
% pour que le document compile même si Fira ou New Computer Modern
% n'est pas installé sur la machine.
\setmainfont{TeX Gyre Termes}
\IfFontExistsTF{Fira Sans}
  {\setsansfont{Fira Sans}[Scale=MatchLowercase]}
  {\setsansfont{TeX Gyre Heros}[Scale=MatchLowercase]}
\IfFontExistsTF{Fira Mono}
  {\setmonofont{Fira Mono}[Scale=MatchLowercase]}
  {\setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]}

\RequirePackage{unicode-math}
\IfFontExistsTF{NewCMMath-Book.otf}
  {\setmathfont{NewCMMath-Book}}
  {\setmathfont{Latin Modern Math}}

% ── Couleurs et longueurs de la maquette ────────────────────────────
\RequirePackage{xcolor}
\RequirePackage{livrejs-couleurs}  % palette partagée avec les figures autonomes

% Décalage du label dans la marge (ajustable dans le document :
%   \setlength{\deflabeloffset}{2.5cm} )
\newlength{\deflabeloffset}
\setlength{\deflabeloffset}{3cm}

% ── Titres ──────────────────────────────────────────────────────────
\RequirePackage{titlesec}

% \chapter
\titleformat{\chapter}
  [block]
  {\LARGE\sffamily\bfseries\color{sectioncolor}}
  {\hspace*{-\deflabeloffset}\thechapter}
  {1em}
  {}
  [\vspace{3pt}\leavevmode\hspace*{-\deflabeloffset}%
   \textcolor{sectioncolor}{\rule{\dimexpr\textwidth+\deflabeloffset\relax}{0.8pt}}]
\titlespacing*{\chapter}{0pt}{2\baselineskip}{1.5\baselineskip}

% \chapter* (chapitres non numérotés)
\titleformat{name=\chapter,numberless}
  [block]
  {\LARGE\sffamily\bfseries\color{sectioncolor}}
  {}
  {0pt}
  {}
  [\vspace{3pt}\leavevmode\hspace*{-\deflabeloffset}%
   \textcolor{sectioncolor}{\rule{\dimexpr\textwidth+\deflabeloffset\relax}{0.8pt}}]

% \section : numéro dans la marge, titre à droite, filet étendu
\titleformat{\section}
  [block]
  {\large\sffamily\bfseries\color{sectioncolor}}
  {\hspace*{-\deflabeloffset}\thesection}
  {1em}
  {}
  [\vspace{2pt}\leavevmode\hspace*{-\deflabeloffset}%
   \textcolor{sectioncolor}{\rule{\dimexpr\textwidth+\deflabeloffset\relax}{0.4pt}}]
\titlespacing*{\section}{0pt}{1.5\baselineskip}{0.75\baselineskip}

% \subsection : numéro dans la marge, titre à droite
\titleformat{\subsection}
  [block]
  {\normalsize\sffamily\bfseries\color{sectioncolor}}
  {\hspace*{-\deflabeloffset}\thesubsection}
  {1em}
  {}
\titlespacing*{\subsection}{0pt}{\baselineskip}{0.5\baselineskip}

% \subsubsection : style classique
\titleformat{\subsubsection}
  {\normalsize\sffamily\color{sectioncolor}}
  {\thesubsubsection}{1em}{}

% ── Mise en page ────────────────────────────────────────────────────
\RequirePackage[left=5cm, right=2.5cm, top=2.5cm, bottom=2.5cm]{geometry}
\RequirePackage{microtype}
\RequirePackage{parskip}
\RequirePackage{needspace}

% ── En-têtes de page ─────────────────────────────────────────────────
\RequirePackage{fancyhdr}
\pagestyle{fancy}
\fancyhf{}
% Nom du chapitre sans majuscules forcées, en gris
\renewcommand{\chaptermark}[1]{%
  \markboth{\chaptertitlename\ \thechapter.\ #1}{}}
\fancyhead[L]{\small\color{gray!70}\leftmark}
\fancyhead[R]{\small\color{gray!70}\thepage}
% Filet sous l'en-tête, discret
\renewcommand{\headrulewidth}{0.3pt}
\renewcommand{\headrule}{%
  {\color{gray!30}\hrule width\headwidth height\headrulewidth}\vskip-\headrulewidth}
% Page d'ouverture de chapitre : numéro de page centré en bas, sans en-tête
\fancypagestyle{plain}{%
  \fancyhf{}
  \renewcommand{\headrulewidth}{0pt}
  \fancyfoot[C]{\small\color{gray!70}\thepage}}

% ── Commandes mathématiques personnalisées ───────────────────────────
\RequirePackage{xstring}

\ifjs@commandes
  \RequirePackage{commandesJS}  % \eu, \P{}, \Es{}, \loiexponentielle, \intfo, \Rp, \Ns, etc.
  % tipa (chargé par commandesJS) redéfinit \!, \; et \: comme accents
  % phonétiques ; on restaure leur sens mathématique usuel (espacements).
  \let\tipaexclam\!
  \renewcommand{\!}{\ifmmode\mspace{-3mu}\else\tipaexclam\fi}
  \let\tipasemicolon\;
  \renewcommand{\;}{\ifmmode\mspace{5mu plus 5mu}\else\tipasemicolon\fi}
  \let\tipacolon\:
  \renewcommand{\:}{\ifmmode\mspace{4mu plus 2mu minus 4mu}\else\tipacolon\fi}
\fi

\RequirePackage{diffcoeff}     % \dl (différentielle droite dans les intégrales)

% Fonction de survie : \survie{F} -> \overline{F}
% Le contenu est décalé vers la gauche (sans changer la largeur de la boîte),
% ce qui place la barre plus à droite par rapport au F italique.
\newcommand{\survie}[1]{\overline{\mkern-2mu#1\mkern2mu}}

% Met en évidence un terme défini : gras, dans la couleur des titres de section.
\newcommand{\defi}[1]{\textbf{\color{sectioncolor}#1}}

% \ind{S} donne \mathbb{1}_S ; \ind[x]{S} donne \mathbb{1}_S(x).
\newcommand{\ind}[2][]{\mathbb{1}_{#2}\IfStrEq{#1}{}{}{(#1)}}

% Début et fin d'une démonstration.
\newcommand{\DebutDemonstration}{\textit{Démonstration.}\enspace}
\newcommand{\FinDemonstration}{\qed}

% ── Tableaux, graphiques, figures ────────────────────────────────────
\RequirePackage{booktabs}
\RequirePackage[skins,breakable]{tcolorbox}
\RequirePackage{tikz}
\RequirePackage{eso-pic}   % fond plein bord de la couverture
\usetikzlibrary{arrows.meta}
\RequirePackage{pgfplots}
\usepgfplotslibrary{groupplots}
\pgfplotsset{compat=1.18}
\RequirePackage{graphicx}
\RequirePackage{subcaption}

% ── Icônes des activités ─────────────────────────────────────────────
% Placées dans la marge, à gauche de l'étiquette (exercices, encadrés).
\RequirePackage{fontawesome5}
\newcommand{\iconePython}{{\color{infocolor}\faLaptopCode}}
\newcommand{\iconeClasse}{{\color{classecolor}\faSchool}}

% ── Code source ──────────────────────────────────────────────────────
\RequirePackage{listings}
\renewcommand{\lstlistingname}{Programme}
\definecolor{codebg}{RGB}{248,248,248}
\definecolor{codecomment}{RGB}{100,100,100}

% Réglages communs aux deux langages (évite de tout dupliquer).
\lstdefinestyle{styleJSbase}{
  basicstyle=\small\ttfamily,
  commentstyle=\color{codecomment}\itshape,
  keywordstyle=\color{sectioncolor},
  backgroundcolor=\color{codebg},
  frame=single,
  framerule=0.4pt,
  rulecolor=\color{gray!50},
  xleftmargin=6pt, xrightmargin=6pt,
  aboveskip=0.75\baselineskip,
  belowskip=0.75\baselineskip,
  showstringspaces=false,
  breaklines=true,
  columns=flexible,
  keepspaces=true,
  extendedchars=true,
  literate=
    {é}{{\'e}}1 {è}{{\`e}}1 {ê}{{\^e}}1 {ë}{{\"e}}1
    {à}{{\`a}}1 {â}{{\^a}}1 {ô}{{\^o}}1
    {î}{{\^i}}1 {û}{{\^u}}1 {ù}{{\`u}}1
    {É}{{\'E}}1 {È}{{\`E}}1 {Ç}{{\c{C}}}1 {ç}{{\c{c}}}1,
}
\lstdefinestyle{styleR}{style=styleJSbase, language=R}
% Le code Python est une activité informatique : cadre et mots-clés verts.
\lstdefinestyle{stylePy}{style=styleJSbase, language=Python,
  keywordstyle=\color{infocolor}, rulecolor=\color{infocolor!70}}

% ── Boîtes des environnements ────────────────────────────────────────
\tcbset{thmbox/.style={
  enhanced,
  unbreakable,
  colback=thmboxbg,
  colframe=thmboxbg,
  boxrule=0pt,
  arc=0pt,
  left=10pt,
  right=10pt,
  top=8pt,
  bottom=8pt,
  before skip=0pt,
  after skip=0.5\baselineskip,
  sharp corners,
}}

\tcbset{histbox/.style={
  enhanced,
  breakable,
  colback=histboxbg,
  colframe=sectioncolor,
  boxrule=0pt,
  leftrule=3pt,
  arc=0pt,
  left=10pt,
  right=10pt,
  top=8pt,
  bottom=8pt,
  before skip=0pt,
  after skip=0.5\baselineskip,
  sharp corners,
}}

\tcbset{secbox/.style={
  enhanced,
  breakable,
  colback=secboxbg,
  colframe=classecolor,
  boxrule=0pt,
  leftrule=3pt,
  arc=0pt,
  left=10pt,
  right=10pt,
  top=8pt,
  bottom=8pt,
  before skip=0pt,
  after skip=0.5\baselineskip,
  sharp corners,
}}

\tcbset{infobox/.style={secbox, colback=infoboxbg, colframe=infocolor}}

% ── Environnements de théorèmes ─────────────────────────────────────
% Compteur partagé : Théorème, Proposition, Lemme, Corollaire
\newcounter{thm}[chapter]
\renewcommand{\thethm}{\thechapter.\arabic{thm}}

% Compteurs indépendants
\newcounter{definition}[chapter]
\renewcommand{\thedefinition}{\thechapter.\arabic{definition}}
\newcounter{example}[chapter]
\renewcommand{\theexample}{\thechapter.\arabic{example}}
\newcounter{remark}[chapter]
\renewcommand{\theremark}{\thechapter.\arabic{remark}}
\newcounter{historical}[chapter]
\renewcommand{\thehistorical}{\thechapter.\arabic{historical}}
\newcounter{secondaire}[chapter]
\renewcommand{\thesecondaire}{\thechapter.\arabic{secondaire}}
\newcounter{outil}[chapter]
\renewcommand{\theoutil}{\thechapter.\arabic{outil}}

% Commande interne : label dans la marge, titre au bord du texte
\newcommand{\thmheading}[3]{%
  \Needspace{5\baselineskip}%
  \par\addvspace{0.5\baselineskip}\noindent
  \hspace*{-\deflabeloffset}%
  \makebox[\deflabeloffset][l]{\sffamily\bfseries\color{sectioncolor}#1~#2}%
  {\sffamily\bfseries\color{sectioncolor}#3}\nopagebreak
  \par\addvspace{0.25\baselineskip}\nobreak
}

\newenvironment{theorem}[1]{%
  \refstepcounter{thm}\thmheading{Théorème}{\thethm}{#1}%
  \begin{tcolorbox}[thmbox]}{%
  \end{tcolorbox}}

\newenvironment{proposition}[1]{%
  \refstepcounter{thm}\thmheading{Proposition}{\thethm}{#1}%
  \begin{tcolorbox}[thmbox]}{%
  \end{tcolorbox}}

\newenvironment{lemma}[1]{%
  \refstepcounter{thm}\thmheading{Lemme}{\thethm}{#1}%
  \begin{tcolorbox}[thmbox]}{%
  \end{tcolorbox}}

\newenvironment{corollary}[1]{%
  \refstepcounter{thm}\thmheading{Corollaire}{\thethm}{#1}%
  \begin{tcolorbox}[thmbox]}{%
  \end{tcolorbox}}

\newenvironment{definition}[1]{%
  \refstepcounter{definition}\thmheading{Définition}{\thedefinition}{#1}%
  \begin{tcolorbox}[thmbox]}{%
  \end{tcolorbox}}

\newenvironment{example}[1]{%
  \refstepcounter{example}\thmheading{Exemple}{\theexample}{#1}%
  \begin{tcolorbox}[thmbox]}{%
  \end{tcolorbox}}

\newenvironment{remark}[1]{%
  \refstepcounter{remark}\thmheading{Remarque}{\theremark}{#1}%
  \begin{tcolorbox}[thmbox]}{%
  \end{tcolorbox}}

\newenvironment{historical}[1]{%
  \refstepcounter{historical}%
  \Needspace{5\baselineskip}%
  \par\addvspace{0.5\baselineskip}\noindent
  \hspace*{-\deflabeloffset}%
  \makebox[\deflabeloffset][l]{\sffamily\bfseries\color{sectioncolor}Note historique~\thehistorical}%
  {\sffamily\bfseries\color{sectioncolor}#1}\nopagebreak
  \par\addvspace{0.25\baselineskip}\nobreak
  \begin{tcolorbox}[histbox]}{%
  \end{tcolorbox}}

% « Pour la classe » : remarques qui ramènent une notion vers
% l'enseignement secondaire — boîte à fond ocre, distincte des remarques
% mathématiques ordinaires (thmbox, fond bleu pâle).
\newenvironment{secondaire}[1]{%
  \refstepcounter{secondaire}%
  \Needspace{5\baselineskip}%
  \par\addvspace{0.5\baselineskip}\noindent
  \hspace*{-\deflabeloffset}%
  \llap{\iconeClasse\enspace}%
  \makebox[\deflabeloffset][l]{\sffamily\bfseries\color{classecolor}%
    Pour la classe~\thesecondaire}%
  {\sffamily\bfseries\color{classecolor}#1}\nopagebreak
  \par\addvspace{0.25\baselineskip}\nobreak
  \begin{tcolorbox}[secbox]}{%
  \end{tcolorbox}}

% « Outil » : suggestions d'usage des outils courants au
% secondaire (Desmos, GeoGebra, WolframAlpha) — boîte verte, comme les
% autres activités informatiques.
\newenvironment{outil}[1]{%
  \refstepcounter{outil}%
  \Needspace{5\baselineskip}%
  \par\addvspace{0.5\baselineskip}\noindent
  \hspace*{-\deflabeloffset}%
  \llap{\iconePython\enspace}%
  \makebox[\deflabeloffset][l]{\sffamily\bfseries\color{infocolor}%
    Outil~\theoutil}%
  {\sffamily\bfseries\color{infocolor}#1}\nopagebreak
  \par\addvspace{0.25\baselineskip}\nobreak
  \begin{tcolorbox}[infobox]}{%
  \end{tcolorbox}}

% ── Citation (extraits cités d'une source externe) ──────────────────
\tcbset{citationbox/.style={
  enhanced,
  breakable,
  colback=citationbg,
  colframe=citationbg,
  boxrule=0pt,
  arc=0pt,
  left=26pt,
  right=20pt,
  top=12pt,
  bottom=12pt,
  before skip=1.3\baselineskip,
  after skip=0.5\baselineskip,
  sharp corners,
  borderline west={2.5pt}{0pt}{sectioncolor},
  overlay unbroken={
    \node[anchor=north west, inner sep=0pt, xshift=3pt, yshift=12pt,
          font=\fontsize{52}{52}\selectfont\itshape, color=sectioncolor!30]
      at (frame.north west) {«};
    \node[anchor=south east, inner sep=0pt, xshift=-2pt, yshift=-4pt,
          font=\fontsize{52}{52}\selectfont\itshape, color=sectioncolor!30]
      at (frame.south east) {»};
  },
  overlay first={
    \node[anchor=north west, inner sep=0pt, xshift=3pt, yshift=12pt,
          font=\fontsize{52}{52}\selectfont\itshape, color=sectioncolor!30]
      at (frame.north west) {«};
  },
  overlay last={
    \node[anchor=south east, inner sep=0pt, xshift=-2pt, yshift=-4pt,
          font=\fontsize{52}{52}\selectfont\itshape, color=sectioncolor!30]
      at (frame.south east) {»};
  },
}}

\newenvironment{extrait}{%
  \begin{tcolorbox}[citationbox]}{%
  \end{tcolorbox}}

% ── Faux texte (pratique pour maquetter) ────────────────────────────
\RequirePackage{lipsum}

% ── Exercices et solutions ──────────────────────────────────────────
\RequirePackage{answers}

\newcounter{exercice}[chapter]
\renewcommand{\theexercice}{\thechapter.\arabic{exercice}}

% 'solution' écrit son contenu dans le fichier (invisible en ligne)
\Newassociation{solution}{Sol}{solutions}
\renewcommand{\theSol}{\theexercice}   % label dans le fichier = numéro d'exercice

% Format d'affichage dans l'annexe (quand le fichier est importé)
% L'étiquette reprend la couleur et l'icône de l'exercice (voir plus bas).
\renewenvironment{Sol}[1]{%
  \par\noindent
  \ifcsname typeexo@#1\endcsname
    \IfStrEq{\csname typeexo@#1\endcsname}{python}%
      {\def\couleurSol{infocolor}\llap{\iconePython\enspace}}%
      {\def\couleurSol{classecolor}\llap{\iconeClasse\enspace}}%
  \else\def\couleurSol{sectioncolor}\fi
  % Ancre « sol.<numéro> » visée par l'étiquette de l'exercice ; l'étiquette
  % de la solution renvoie à son tour vers l'exercice dans le texte.
  \hypertarget{sol.#1}{}%
  {\sffamily\bfseries\color{\couleurSol}%
   \ifcsname ancreexo@#1\endcsname
     \hypersetup{linkcolor=\couleurSol}%
     \hyperlink{\csname ancreexo@#1\endcsname}{Exercice~#1.}%
   \else Exercice~#1.\fi}\enspace
}{%
  \par\addvspace{0.5\baselineskip}%
}

% Affichage de l'exercice dans le chapitre : label en marge, pas de fond coloré.
% Options (icône à gauche de l'étiquette, étiquette de la couleur associée) :
%   [python] : exercice qui demande l'usage de Python (vert, ordinateur) ;
%   [classe] : exercice tourné vers l'enseignement secondaire (jaune, école).
%   \begin{exercice}[python]\label{exo:...}
\NewDocumentEnvironment{exercice}{o}{%
  \Needspace{3\baselineskip}%
  \refstepcounter{exercice}%
  % Mémorise l'ancre de l'exercice pour le lien retour du solutionnaire.
  \expandafter\xdef\csname ancreexo@\theexercice\endcsname{\@currentHref}%
  \par\addvspace{0.5\baselineskip}\noindent
  \hspace*{-\deflabeloffset}%
  \def\couleurExercice{sectioncolor}%
  \IfValueT{#1}{%
    \expandafter\xdef\csname typeexo@\theexercice\endcsname{#1}%
    \IfStrEq{#1}{python}{\def\couleurExercice{infocolor}\llap{\iconePython\enspace}}{}%
    \IfStrEq{#1}{classe}{\def\couleurExercice{classecolor}\llap{\iconeClasse\enspace}}{}}%
  \makebox[\deflabeloffset][l]{%
    \sffamily\bfseries\color{\couleurExercice}%
    \hypersetup{linkcolor=\couleurExercice}%
    \hyperlink{sol.\theexercice}{Exercice~\theexercice.}}%
  \ignorespaces
}{%
  \par
}

% Sous-questions d'un exercice, numérotées a), b), c)…
\newenvironment{sousquestions}{%
  \begin{enumerate}%
    \renewcommand{\theenumi}{\alph{enumi}}%
    \renewcommand{\labelenumi}{\theenumi)}%
}{%
  \end{enumerate}%
}

% Ouvre le fichier de solutions du chapitre courant
\newcommand{\sectionExercices}{%
  \section*{Exercices}%
  \Opensolutionfile{solutions}[sol-ch\thechapter]%
}

% Ferme le fichier (à appeler avant chaque nouveau \chapter)
\newcommand{\finExercices}{%
  \Closesolutionfile{solutions}%
}

% Réimporte les solutions d'un chapitre dans l'annexe.
%   \solutionsChapitre{1}{Titre du chapitre}
%   \solutionsChapitre[Annexe]{D}{Titre de l'annexe}
% Ne fait rien si le fichier n'existe pas encore (première compilation).
\newcommand{\solutionsChapitre}[3][Chapitre]{%
  \IfFileExists{sol-ch#2.tex}{%
    \section*{#1 #2 \textendash\ #3}%
    \input{sol-ch#2}%
  }{}%
}

% ── Bibliographie ────────────────────────────────────────────────────
\RequirePackage[style=alphabetic, backend=biber]{biblatex}

% ═══════════════════════════════════════════════════════════════════════
%  Page de couverture
% ═══════════════════════════════════════════════════════════════════════
% Métadonnées : \title, \author, \date (standard) plus les suivantes.
\newcommand{\js@etablissement}{}
\newcommand{\js@departement}{}
\newcommand{\js@soustitre}{}
\newcommand{\etablissement}[1]{\renewcommand{\js@etablissement}{#1}}
\newcommand{\departement}[1]{\renewcommand{\js@departement}{#1}}
\newcommand{\soustitre}[1]{\renewcommand{\js@soustitre}{#1}}

% Motif décoratif de la couverture : nuage de points sur fond sombre,
% ~ largeur pleine page. Tracé à même le tikzpicture de \pagecouverture
% (ce ne sont que des commandes de dessin, pas un tikzpicture complet).
% Redéfinissable :  \motifcouverture{\fill[...] ... ;}
\newcommand{\js@motif}{%
  \foreach \i in {0,...,55}{%
    \pgfmathsetmacro{\ptx}{\i*0.34}
    \pgfmathsetmacro{\pty}{1.35+1.05*sin(\i*11)}
    \pgfmathsetmacro{\ptr}{0.035+0.075*(1+cos(\i*11))/2}
    \pgfmathsetmacro{\ptop}{0.10+0.30*(1+sin(\i*11+40))/2}
    \fill[coveraccent!85!white, opacity=\ptop] (\ptx,\pty) circle (\ptr);
  }}
\newcommand{\motifcouverture}[1]{\renewcommand{\js@motif}{#1}}

% \pagecouverture : compose la page de titre à partir des métadonnées.
% Fond plein bord, titre, bandeau d'auteur — inspirée des couvertures
% classiques de manuel (fond sombre, un seul bandeau de couleur, peu
% d'éléments empilés). Le titre (\title) peut contenir \\.
\newcommand{\pagecouverture}{%
\begin{titlepage}
\thispagestyle{empty}
\AddToShipoutPictureBG*{%
  \AtPageLowerLeft{%
  \begin{tikzpicture}
    % ── Fond plein bord ────────────────────────────────────────────
    \fill[covernavy] (0,0) rectangle (\paperwidth,\paperheight);

    % ── Motif décoratif (entre le titre et le bandeau) ─────────────
    % NB : dès qu'un nombre est combiné par + ou - avec \paperwidth ou
    % \paperheight dans une même expression, on lui donne une unité
    % explicite (cm) — sans quoi pgfmath mélange les échelles et le
    % résultat atterrit hors-page.
    \begin{scope}[shift={(1.1cm,\paperheight-11.2cm-5.6cm)}]
      \clip (0,0) rectangle (\paperwidth-2.2cm,5.6cm);
      \js@motif
    \end{scope}

    % ── Bande du titre (pleine largeur, comme le bandeau d'auteur) ──
    \fill[coveraccent] (0,\paperheight-8.0cm) rectangle (\paperwidth,\paperheight-4.6cm);
    \node[anchor=north, text=covernavy, align=center,
          text width=\paperwidth-4.4cm, inner sep=0pt]
      at (0.5\paperwidth,\paperheight-4.85cm)
      {\sffamily\bfseries\fontsize{30}{35}\selectfont \@title};

    % ── Sous-titre (sous la bande) ───────────────────────────────────
    \node[anchor=north, text=white!80!covernavy, align=center,
          text width=\paperwidth-4.4cm, inner sep=0pt]
      at (0.5\paperwidth,\paperheight-8.5cm)
      {\normalfont\sffamily\Large \js@soustitre};

    % ── Bandeau d'auteur ─────────────────────────────────────────────
    %\fill[coveraccent] (0,9.0) rectangle (\paperwidth,11.3);
    \node[anchor=south, text=covernavy, font=\sffamily\bfseries\Large]
      at (0.5\paperwidth,10.15) {\color{white}\@author};

    % ── Établissement et date (petits caractères, bas de page) ──────
    \node[anchor=south, text=white!65!covernavy, font=\sffamily\footnotesize]
      at (0.5\paperwidth,5.9)
      {\MakeUppercase{\addfontfeature{LetterSpace=4.0}%
        \js@etablissement\ \textbullet\ \js@departement}};
    \node[anchor=south, text=white!40!covernavy, font=\sffamily\scriptsize]
      at (0.5\paperwidth,4.9) {\MakeUppercase{\@date}};
  \end{tikzpicture}}}
\null
\end{titlepage}
\ClearShipoutPictureBG}

% \pagecredits[Titre]{texte} : deuxième de couverture (licence, mentions,
% déclaration sur l'usage de l'IA, remerciements…).
\newcommand{\pagecredits}[2][À propos de ce document]{%
\newpage
\thispagestyle{empty}
\vspace*{\fill}

\begingroup
\renewcommand{\labelitemi}{\textcolor{sectioncolor}{\small\textbullet}}
\small

\vspace{1cm}
\noindent{\sffamily\bfseries\color{sectioncolor}\large #1}\\[2pt]
{\color{sectioncolor}\rule{\linewidth}{0.6pt}}

\medskip
\noindent #2
\endgroup

\vspace*{\fill}
\newpage}

% ── Hyperliens (toujours en dernier) ─────────────────────────────────
\RequirePackage{hyperref}
\hypersetup{
  colorlinks=true,
  linkcolor=sectioncolor,
  citecolor=sectioncolor,
  urlcolor=sectioncolor,
}

\endinput
