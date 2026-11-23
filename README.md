# Introduction aux nombres complexes et polynômes

Notes de cours de Jérôme Soucy (Université Laval), écrites à l'intention des étudiantes et étudiants des cours *MAT-1900 : Mathématiques de l'ingénieur 1* et *MAT-1110 : Calcul des fonctions de plusieurs variables*. C'est une ressource éducative libre.

- **Lire en ligne :** <https://complexe.mathematiques.art/>
- **Télécharger le PDF :** [Introduction-nombres-complexes.pdf](https://complexe.mathematiques.art/Introduction-nombres-complexes.pdf)

[![Licence CC BY-NC-SA 4.0](https://img.shields.io/badge/licence-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.fr)

## Contenu

1. **Arithmétique élémentaire.** Associativité, commutativité, distributivité, stabilité d'un ensemble de nombres ; pourquoi on a dû introduire de nouveaux nombres.
2. **Définition des nombres complexes.** Unité imaginaire, forme cartésienne, somme, produit, inverse et quotient.
3. **Module et conjugué.** Définitions, propriétés et inégalité triangulaire.
4. **Lieux géométriques dans le plan complexe.** Cercles, ellipses, hyperboles.
5. **Exercices — série 1.**
6. **Forme polaire.** Argument principal.
7. **La fonction exponentielle complexe.** Théorème d'Euler, forme exponentielle.
8. **Les formules d'Euler et celle de De Moivre.**
9. **Racines $n$-ièmes.**
10. **Exercices — série 2.**

Le document comprend aussi les solutions des exercices et une bibliographie. Sur le site, les solutions se déplient sous chaque exercice (certaines sont présentées en vidéo) ; dans le PDF, elles sont regroupées à la fin.

## Réutiliser et adapter ces notes

Ces notes sont distribuées sous la licence [Creative Commons Attribution – Pas d'utilisation commerciale – Partage dans les mêmes conditions 4.0 International](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.fr) (CC BY-NC-SA 4.0). Vous pouvez les copier, les modifier, les traduire et en réutiliser des parties pour votre propre enseignement, aux conditions suivantes :

- citer l'auteur original et indiquer les modifications apportées ;
- ne pas en faire un usage commercial ;
- diffuser votre version sous la même licence.

Pour adapter les notes, le plus simple est de faire un *fork* de ce dépôt : la source unique produit le site web et le PDF. Les détails se trouvent dans [LICENSE.md](LICENSE.md).

**Pour citer ce document :** Jérôme Soucy, *Introduction aux nombres complexes et polynômes*, notes des cours MAT-1900 et MAT-1110, Université Laval, 2026. <https://complexe.mathematiques.art/>

## Compiler le document

Les sources sont écrites en [Quarto](https://quarto.org) (Markdown) et se trouvent dans [`quarto/`](quarto/). Le PDF est composé par LaTeX avec une classe sur mesure.

Il faut :

- Quarto (testé avec la version 1.10) ;
- une distribution LaTeX avec `lualatex` et `biber`, par exemple `quarto install tinytex` ; la liste des paquets nécessaires figure dans le [workflow de publication](.github/workflows/publish.yml) ;
- Python 3 et `pdftocairo` (Poppler), qui servent à convertir les figures TikZ en SVG pour le web.

Puis :

```sh
cd quarto
quarto render            # site web et PDF dans quarto/_book/
quarto preview           # aperçu web mis à jour à chaque enregistrement
```

Pour écrire ou modifier un chapitre (environnements, figures, renvois, exercices, vidéos), consultez [`quarto/LISEZMOI.md`](quarto/LISEZMOI.md).

À chaque poussée sur `main`, GitHub Actions rend le site et le PDF, puis les publie sur GitHub Pages.

## Organisation du dépôt

| Dossier | Contenu |
|---|---|
| [`quarto/`](quarto/) | Sources du document : chapitres (`*.qmd`), configuration (`_quarto.yml`), bibliographie |
| [`quarto/latex/`](quarto/latex/) | Classe LaTeX, macros et gabarit du PDF |
| [`quarto/_filtres/`](quarto/_filtres/) | Filtres Lua qui traduisent le Markdown en LaTeX (PDF) ou en HTML (web) |
| [`quarto/figures/`](quarto/figures/) | Figures TikZ et leurs versions SVG pour le web |
| [`quarto/styles/`](quarto/styles/) | Thème du site, polices, style bibliographique |
| [`NbComplexes_old/`](NbComplexes_old/) | Ancienne version Quarto du site (archive) |

## Signaler une erreur

Ouvrez une [*issue*](https://github.com/soucyj/NbComplexes/issues) ou écrivez à [jerome.soucy@mat.ulaval.ca](mailto:jerome.soucy@mat.ulaval.ca). Les suggestions de correction sous forme de *pull request* sont aussi les bienvenues.

## Avis d'utilisation de l'IA

Des outils d'IA (principalement Claude Opus 5.5) ont servi à convertir le document au format Quarto/LaTeX, à adapter les figures TikZ et à corriger certaines coquilles. L'auteur a ensuite vérifié et validé le contenu.
