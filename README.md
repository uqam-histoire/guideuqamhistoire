Super brief guide to updating:

Switch to staging

Upload new Guide_1er_cycle_2025_VF.docx

Commit to staging

Watch Actions

Check:

[/preview/](https://uqam-histoire.github.io/guideuqamhistoire/preview/)

preview PDF

If good, make PR staging → main


# README – Guide étudiant du Département d’histoire (UQAM)
Préparé par R.M. Pollard (30-3-2026)

## 1. Objet de ce dépôt

Ce dépôt sert à produire et publier automatiquement **deux versions concordantes** du *Guide à l’intention des étudiants et des étudiantes de premier cycle en histoire et en archivistique* :

1. une **version PDF imprimable** ;
2. une **version HTML** plus agréable à lire sur téléphone ou écran.

L’idée directrice est simple : **on maintient un seul document source, en Word**, et le système fabrique automatiquement les deux sorties. Cela évite la dérive entre plusieurs versions, réduit les risques d’erreur, et permet de servir des usages différents :

- lecture rapide sur mobile ;
- consultation et impression en PDF ;
- diffusion publique à partir d’une seule source.

---

## 2. Résumé du fonctionnement général

Le dépôt contient un fichier Word source, des fichiers auxiliaires (gabarit HTML, CSS, images d’annexes, filtre Lua), et des **workflows GitHub Actions**.

Quand le fichier Word est mis à jour dans le dépôt :

- un workflow reconstruit le **PDF** ;
- le même workflow reconstruit aussi la **version HTML** ;
- le résultat est publié automatiquement sur **GitHub Pages**.

Le système a été conçu avec deux environnements :

- **production** : le site public principal ;
- **prévisualisation** : un miroir de test, pour vérifier des changements de mise en forme sans risquer de casser la version publique.

En pratique :

- la branche **`main`** sert à la **production** ;
- la branche **`staging`** sert à la **prévisualisation** ;
- la branche **`gh-pages`** contient les fichiers effectivement publiés par GitHub Pages.

---

## 3. Pourquoi cette solution a été mise en place

Avant cette mise en place, il aurait fallu maintenir séparément :

- un PDF propre à imprimer ;
- une version Web ou mobile ;
- et s’assurer manuellement qu’ils restent identiques.

Cette solution automatisée répond à plusieurs besoins :

### 3.1. Cohérence éditoriale
Le contenu source reste unique. On évite que le PDF et la version HTML divergent.

### 3.2. Simplicité pour l’équipe
On continue à travailler en Word, ce qui est l’outil le plus naturel pour la plupart des collègues.

### 3.3. Accessibilité et lisibilité
La version HTML est plus confortable sur mobile, tandis que le PDF reste utile pour l’impression et l’archivage.

### 3.4. Réduction des erreurs
Les étapes répétitives (conversion, copie des ressources, nettoyage de certaines anomalies, publication) sont automatisées.

### 3.5. Prévisualisation sûre
Les changements de mise en forme peuvent être testés sur une page d’aperçu avant d’être envoyés vers la version publique.

---

## 4. Architecture du dépôt

## 4.1. Fichier source principal

Le document maître est le fichier Word :

`Guide_1er_cycle_2025_VF.docx`

C’est lui qui sert de base pour les deux sorties.

## 4.2. Dossier `assets/`

Le dossier `assets/` contient les éléments nécessaires à la conversion HTML :

- `uqam-guide.css` : feuille de style principale pour l’affichage HTML ;
- `pandoc.html5` : gabarit HTML utilisé par Pandoc ;
- `section-tagger.lua` : filtre Lua qui aide à repérer et baliser certaines parties du document ;
- `images/annex-title.png`
- `images/annex-toc.png`
- `images/annex-notes.png`

Ces trois images servent à remplacer en HTML certaines annexes qui sont mieux représentées comme **images fixes** que comme texte reconstruit.

## 4.3. Workflows GitHub

Le dépôt utilise en général deux workflows :

- `build-guide.yml` : workflow de **production** ;
- `build-preview.yml` : workflow de **prévisualisation**.

Leur logique est volontairement presque identique. La différence principale est le lieu de publication :

- la production publie à la racine du site ;
- la prévisualisation publie dans le sous-dossier `/preview/`.

---

## 5. Ce que fait le pipeline de construction

## 5.1. Installation des outils

Le workflow installe notamment :

- **LibreOffice** pour convertir le Word en PDF ;
- **Pandoc** pour convertir le Word en HTML ;
- **ExifTool** pour écrire les métadonnées du PDF ;
- **qpdf** et **poppler-utils** pour certaines corrections du PDF ;
- les polices Microsoft de base, notamment **Times New Roman**, afin d’obtenir un PDF cohérent avec les attentes typographiques.

## 5.2. Préparation du dossier `dist`

Le workflow crée un dossier de sortie, généralement `dist/`, et y copie :

- la feuille de style CSS ;
- les images nécessaires à l’affichage HTML.

C’est ce dossier `dist/` qui sera ensuite publié.

## 5.3. Construction du PDF

Le Word source est converti en PDF avec LibreOffice.

Le workflow applique aussi plusieurs corrections et enrichissements :

- ajout de métadonnées (titre, auteur, sujet, mots-clés) ;
- suppression d’une page blanche parasite après la table des matières, **si** cette page est vide ;
- conservation d’un PDF propre à diffuser et à imprimer.

## 5.4. Construction du HTML

Pandoc convertit le document Word en HTML.

La conversion utilise :

- un gabarit HTML ;
- la feuille de style CSS ;
- un filtre Lua ;
- une table des matières générée automatiquement ;
- la numérotation des sections.

## 5.5. Post-traitements HTML

Après la conversion Pandoc, plusieurs ajustements sont appliqués directement au HTML généré.

Ils ont été ajoutés progressivement pour résoudre des problèmes concrets.

### a) Remplacement des annexes par des images

Certaines annexes (page titre, table des matières type, exemple de notes/citations) s’affichent mieux en image. Le workflow remplace donc le contenu textuel correspondant par trois figures :

- `annex-title.png`
- `annex-toc.png`
- `annex-notes.png`

### b) Suppression de notes de bas de page résiduelles

Lorsque l’ancienne annexe textuelle a été remplacée par une image, deux notes de bas de page restaient parfois au bas de la page HTML. Le workflow les supprime.

### c) Suppression de la table des matières interne du document Word

Le document Word contient sa propre table des matières, utile dans le fichier source, mais redondante dans la version HTML. Le workflow retire donc cette table des matières “interne” du corps du texte, tout en conservant la table des matières HTML repliable en tête de page.

### d) Suppression d’un paragraphe parasite « Table des matières »

Un paragraphe isolé `<p><strong>Table des matières</strong></p>` persistait parfois dans le HTML. Une étape finale le supprime explicitement.

### e) Ajustements de l’interface supérieure

L’interface HTML a été retouchée pour améliorer la cohérence :

- retrait du bouton de table des matières dans la barre supérieure ;
- maintien d’un bloc repliable au début de la page pour la navigation ;
- ajustements de style pour la lisibilité mobile.

---

## 6. Publication

## 6.1. Site public (production)

La version de production est publiée à la racine du site GitHub Pages.

Adresse typique :

- `https://uqam-histoire.github.io/guideuqamhistoire/`

## 6.2. Site d’aperçu (preview)

La version de prévisualisation est publiée dans un sous-dossier :

- `https://uqam-histoire.github.io/guideuqamhistoire/preview/`

Cela permet de tester des changements de rendu sans toucher au site public.

## 6.3. Pourquoi `keep_files: true` est important

Les workflows utilisent `keep_files: true` lors de la publication sur `gh-pages`.

C’est essentiel, car sinon une publication de production pourrait effacer le sous-dossier `preview/`, ou inversement.

---

## 7. Branches et logique de travail

## 7.1. Branche `main`
Elle correspond à la version stable et publique.

Une modification fusionnée dans `main` déclenche la reconstruction de la version publique.

## 7.2. Branche `staging`
Elle sert à tester les changements, notamment de mise en page ou de CSS.

Une modification poussée dans `staging` déclenche la reconstruction de la version d’aperçu.

## 7.3. Branche `gh-pages`
Cette branche n’est pas modifiée à la main en temps normal. Elle est alimentée automatiquement par les workflows.

---

## 8. Procédure recommandée pour mettre à jour le Guide étudiant

Voici la procédure conseillée lorsqu’on veut publier une nouvelle version du Guide.

## 8.1. Étape 1 – Préparer le nouveau fichier Word

Partir du document Word existant et le mettre à jour.

Il vaut mieux **conserver autant que possible la structure du document précédent**, notamment :

- les titres hiérarchisés ;
- l’organisation générale ;
- les intitulés d’annexes ;
- les grandes sections.

Autrement dit, il est préférable de **modifier l’ancien fichier** plutôt que d’en repartir complètement de zéro.

## 8.2. Étape 2 – Travailler sur `staging`

Faire les changements d’abord sur la branche `staging`.

Cela permet de tester :

- le rendu mobile ;
- le PDF ;
- la table des matières HTML ;
- les annexes ;
- la disparition des éléments parasites.

## 8.3. Étape 3 – Remplacer le fichier source

Remplacer dans le dépôt le fichier :

`Guide_1er_cycle_2025_VF.docx`

par la nouvelle version.

## 8.4. Étape 4 – Commit et push

Faire un commit, puis pousser les changements sur `staging`.

Cela déclenche automatiquement le workflow de prévisualisation.

## 8.5. Étape 5 – Vérifier la version d’aperçu

Relire soigneusement :

- la page HTML de preview ;
- le PDF généré ;
- le début de page ;
- les annexes ;
- les notes ;
- la fin du document.

## 8.6. Étape 6 – Fusionner vers `main`

Quand tout est correct, ouvrir une **Pull Request** de `staging` vers `main`, puis la fusionner.

Cela déclenche la reconstruction de la version publique.

---

## 9. Checklist pratique de mise à jour

### Checklist minimale
- [ ] Le nouveau Word a bien remplacé l’ancien.
- [ ] Les titres et sous-titres sont toujours hiérarchisés proprement.
- [ ] Les annexes attendues sont toujours présentes et correctement intitulées.
- [ ] Le workflow de preview s’est exécuté sans erreur.
- [ ] Le HTML de preview est lisible sur mobile.
- [ ] Le PDF s’ouvre correctement.
- [ ] La page blanche parasite n’est pas revenue dans le PDF.
- [ ] Les trois images d’annexes sont présentes à la fin du HTML.
- [ ] Il n’y a pas de paragraphe parasite « Table des matières » au début.
- [ ] Il n’y a pas de notes de bas de page résiduelles en fin de document.
- [ ] La Pull Request `staging` → `main` a bien été fusionnée.
- [ ] Le site public a été reconstruit avec succès.

### Checklist éditoriale
- [ ] Les noms des programmes sont à jour.
- [ ] Les règlements et ressources mentionnés sont à jour.
- [ ] Les liens internes fonctionnent.
- [ ] Les références bibliographiques s’affichent convenablement.
- [ ] Les exemples d’annexes sont toujours pertinents.

---

## 10. Conseils importants sur le fichier Word

Le système fonctionne mieux si le document Word garde une structure comparable à l’ancien.

### À faire
- utiliser les styles de titres Word de façon cohérente ;
- conserver les intitulés de sections autant que possible ;
- garder les annexes dans une forme reconnaissable ;
- vérifier la cohérence de la table des matières Word dans le document source.

### À éviter
- reconstruire entièrement le document avec une structure radicalement différente ;
- transformer des titres en simple texte gras ;
- déplacer arbitrairement les annexes sans vérifier le rendu HTML ;
- modifier profondément les intitulés d’annexes sans tester la preview.

---

## 11. Gestion des conflits Git

Le fichier Word `.docx` est un fichier binaire. En cas de conflit de fusion entre branches, GitHub ne peut pas le résoudre dans l’interface Web.

Il faut alors :

1. résoudre le conflit localement ;
2. choisir quelle version du `.docx` garder ;
3. faire le commit de résolution ;
4. repousser sur la branche concernée.

En cas de doute, il vaut mieux comparer localement les deux versions du Word avant de trancher.

---

## 12. Pannes fréquentes et dépannage

## 12.1. La page `/preview/` renvoie 404
Causes possibles :

- la branche `staging` n’a pas redéployé la preview ;
- `build-preview.yml` n’est pas présent sur `staging` ;
- un déploiement de production a écrasé `preview/` faute de `keep_files: true`.

Que faire :

- vérifier le workflow de preview ;
- relancer manuellement le workflow sur `staging` ;
- pousser un commit vide sur `staging` si nécessaire.

## 12.2. Une page blanche revient dans le PDF
Le pipeline contient une étape de suppression de la page 3 si elle est vide. Si le problème réapparaît, vérifier que l’étape utilisant `pdftotext` et `qpdf` est toujours présente.

## 12.3. Des notes de bas de page bizarres réapparaissent à la fin du HTML
Cela vient généralement d’un reste de l’ancienne annexe textuelle. Vérifier que l’étape de suppression des notes parasites est toujours active.

## 12.4. Une annexe image manque
Vérifier :

- que l’image existe bien dans `assets/images/` ;
- qu’elle est copiée dans `dist/assets/images/` ;
- que l’étape de remplacement des annexes fonctionne encore.

## 12.5. La table des matières Word réapparaît dans le corps du HTML
Vérifier que l’étape de suppression de cette table des matières est toujours présente dans le workflow.

## 12.6. Le paragraphe parasite « Table des matières » réapparaît
Vérifier que l’étape finale très spécifique de suppression de ce paragraphe est toujours exécutée **en dernier**, juste avant le déploiement.

## 12.7. La preview fonctionne, mais la production est différente
Vérifier que :

- `build-guide.yml` et `build-preview.yml` ont bien les mêmes étapes ;
- la seule différence réelle entre eux est la branche de déclenchement et le lieu de publication.

---

## 13. Ce qu’il faut modifier si l’on veut changer le rendu

### Pour modifier le style général HTML
Modifier :

`assets/uqam-guide.css`

### Pour modifier la structure HTML
Modifier :

`assets/pandoc.html5`

### Pour modifier la logique de repérage de certaines sections
Modifier :

`assets/section-tagger.lua`

### Pour modifier la logique de publication
Modifier :

- `.github/workflows/build-guide.yml`
- `.github/workflows/build-preview.yml`

---

## 14. Recommandation de bonne pratique

La règle la plus importante est la suivante :

> **Toujours tester d’abord sur `staging`, puis fusionner vers `main` seulement quand la preview est satisfaisante.**

Autrement dit :

1. on expérimente sur `staging` ;
2. on vérifie la preview ;
3. on corrige si nécessaire ;
4. on fusionne vers `main` ;
5. on laisse la production se reconstruire automatiquement.

---

## 15. En une phrase

Le système a été conçu pour que le département n’ait à maintenir **qu’un seul document Word**, tout en offrant automatiquement aux étudiantes et étudiants **deux formats concordants**, l’un pour l’impression et l’autre pour la lecture Web/mobile.

---

## 16. Aide-mémoire ultra-court

### Pour mettre à jour le Guide
1. Modifier le fichier Word.
2. Pousser sur `staging`.
3. Vérifier `/preview/` et le PDF.
4. Ouvrir une Pull Request `staging` → `main`.
5. Fusionner.
6. Vérifier le site public.

### Pour corriger le style
1. Modifier CSS / template / workflow sur `staging`.
2. Vérifier `/preview/`.
3. Fusionner vers `main`.

