# Zero-to-Deploy

Application Spring Boot "Hello World" affichant dynamiquement son environnement (**test** / **preprod** / **prod**), avec pipeline CI/CD complète : build, tests, analyse de qualité SonarCloud, dockerisation, publication sur registre, et déploiement continu sur VPS.

---

## Sommaire

- [Environnements déployés](#environnements-déployés)
- [Architecture du projet](#architecture-du-projet)
- [Prérequis sur le serveur cible (VPS)](#prérequis-sur-le-serveur-cible-vps)
- [Configuration des Credentials CI/CD](#configuration-des-credentials-cicd)
    - [Secrets au niveau du dépôt](#secrets-au-niveau-du-dépôt)
    - [Variables au niveau du dépôt](#variables-au-niveau-du-dépôt)
    - [Variables par environnement (GitHub Environments)](#variables-par-environnement-github-environments)
- [Déclencher et suivre la pipeline](#déclencher-et-suivre-la-pipeline)
- [Scénarios de test](#scénarios-de-test)
- [Développement local](#développement-local)
- [Structure du dépôt](#structure-du-dépôt)

---

## Environnements déployés

| Environnement | URL | Branche |
|---|---|---|
| 🔵 Test | [http://164.132.99.131:3000/](http://164.132.99.131:3000/) | `test` |
| 🟠 Preprod | [http://164.132.99.131:3001/](http://164.132.99.131:3001/) | `preprod` |
| 🔴 Prod | [http://164.132.99.131:3002/](http://164.132.99.131:3002/) | `prod` |

---

## Architecture du projet

| Composant | Détail |
|---|---|
| Langage / Framework | Java 17, Spring Boot 3.3.4 |
| Build | Maven (via Maven Wrapper `mvnw`) |
| Conteneurisation | Docker multi-stage (`eclipse-temurin:17-jdk-alpine` puis `17-jre-alpine`, layertools) |
| Registre d'images | Docker Hub (`brice99/zero-to-deploy`) |
| Analyse de qualité | SonarCloud (organisation `bricengueti`) |
| Orchestration locale/serveur | Docker Compose |
| Déploiement | SSH vers un VPS unique hébergeant les 3 environnements |
| CI/CD | GitHub Actions |

Le port interne du conteneur est **fixe (`8090`)** dans les 3 environnements. Seul le port exposé côté hôte varie :

| Environnement | Port hôte | Branche Git |
|---|---|---|
| test | 3000 | `test` |
| preprod | 3001 | `preprod` |
| prod | 3002 | `prod` |

---

## Prérequis sur le serveur cible (VPS)

Le VPS doit être préparé **une seule fois**, manuellement, avant le premier déploiement automatisé. Le script `init-server.sh` (fourni dans ce dépôt) réalise cette préparation :

1. **Mise à jour du système** (`apt-get update && upgrade`)
2. **Installation de Docker** (via `get.docker.com`)
3. **Création d'un utilisateur dédié `cicd`**, ajouté au groupe `docker` (pas de déploiement via `root`)
4. **Génération d'une paire de clés SSH** pour l'utilisateur `cicd`, avec la clé publique ajoutée à `authorized_keys`
5. **Configuration du firewall (UFW)** : ouverture du port SSH (22) et des ports applicatifs (3000, 3001, 3002)
6. **Durcissement SSH** : `PermitRootLogin no`, limitation des tentatives d'authentification, timeouts de session
7. **Création des répertoires de déploiement**, un par environnement :
   ```
   /home/cicd/zero-to-deploy/test
   /home/cicd/zero-to-deploy/preprod
   /home/cicd/zero-to-deploy/prod
   ```

### Exécution du script

```bash
ssh root@<IP_DU_VPS>
# Coller/uploader init-server.sh, puis :
chmod +x init-server.sh
./init-server.sh
```

**Important** : à la fin de l'exécution, la clé SSH **privée** de l'utilisateur `cicd` est affichée dans le terminal. Copiez-la immédiatement — elle ne sera plus jamais affichée — et collez-la dans le secret GitHub `VPS_SSH_KEY` (voir section suivante). Ne la partagez ou ne la collez nulle part ailleurs (chat, ticket, email).

### Résumé des prérequis

| Élément | Détail |
|---|---|
| OS | Toute distribution supportée par `get.docker.com` (Ubuntu/Debian recommandé) |
| Accès initial | `root` (ou `sudo`), une seule fois pour lancer le script |
| Utilisateur de déploiement | `cicd`, créé automatiquement par le script, membre du groupe `docker` |
| Ports ouverts | 22 (SSH), 3000, 3001, 3002 (applicatifs) |
| Espace disque | Prévoir de la marge pour les images Docker (build multi-stage + historique de versions) |

---

## Configuration des Credentials CI/CD

GitHub Actions distingue deux types de valeurs :

- **Secrets** : valeurs chiffrées, jamais réaffichées après création — réservées aux vraies données sensibles (clés privées, tokens, mots de passe).
- **Variables** : valeurs en clair, visibles dans les logs — pour la configuration non sensible.

Et deux niveaux :

- **Niveau dépôt** (`Settings → Secrets and variables → Actions`) : accessible depuis n'importe quel job, peu importe l'environnement actif.
- **Niveau Environment** (`Settings → Environments → <nom>`) : spécifique à un environnement (`test`/`preprod`/`prod`), prioritaire sur le niveau dépôt en cas de doublon.

### Secrets au niveau du dépôt

À créer une seule fois, dans `Settings → Secrets and variables → Actions → Secrets → New repository secret` :

| Secret | Description | Où l'obtenir |
|---|---|---|
| `VPS_SSH_KEY` | Clé SSH **privée** de l'utilisateur `cicd` | Affichée une seule fois à la fin de `init-server.sh` |
| `VPS_USER` | Utilisateur SSH de déploiement | `cicd` |
| `SONAR_TOKEN` | Jeton d'authentification SonarCloud | SonarCloud → *My Account → Security → Generate Token* |
| `DOCKERHUB_TOKEN` | Jeton d'accès Docker Hub | Docker Hub → *Account Settings → Security → New Access Token* |

### Variables au niveau du dépôt

À créer une seule fois, dans le même écran, onglet **Variables** :

| Variable | Description | Exemple |
|---|---|---|
| `DOCKERHUB_USERNAME` | Identifiant Docker Hub | `brice99` |
| `SONAR_ORGANIZATION` | Organisation SonarCloud | `bricengueti` |
| `SONAR_PROJECT_KEY` | Clé du projet SonarCloud | `bricengueti_Zero-to-deploy` |
| `VPS_HOST` | Adresse IP ou nom de domaine du VPS — variable (pas secret), pour rester affichable dans le résumé de pipeline | Fourni par l'hébergeur du VPS |

### Variables par environnement (GitHub Environments)

À créer dans `Settings → Environments`, en créant 3 environnements (`test`, `preprod`, `prod`) — **le nom de l'environnement doit correspondre exactement au nom de la branche Git associée**, la pipeline s'appuie dessus pour choisir automatiquement les bonnes valeurs.

Pour chaque environnement, ajouter ces 5 variables (`Add variable`, pas `Add secret`) :

| Variable | Rôle | Exemple (`test`) | Exemple (`preprod`) | Exemple (`prod`) |
|---|---|---|---|---|
| `IMAGE_NAME` | Nom du dépôt Docker Hub — **identique dans les 3 environnements** | `brice99/zero-to-deploy` | `brice99/zero-to-deploy` | `brice99/zero-to-deploy` |
| `IMAGE_TAG` | Tag de l'image — seul élément qui différencie l'environnement au niveau image | `test` | `preprod` | `prod` |
| `ENVIRONMENT` | Pilote `spring.profiles.active`, détermine le fichier `application-{env}.properties` chargé | `test` | `preprod` | `prod` |
| `HOST_PORT` | Port exposé côté VPS | `3000` | `3001` | `3002` |
| `CONTAINER_NAME` | Nom du conteneur Docker sur le VPS | `zero-to-deploy-test` | `zero-to-deploy-preprod` | `zero-to-deploy-prod` |

> **Pourquoi `IMAGE_NAME` est identique partout ?** Le projet suit le principe *build once, deploy everywhere* : la même image Docker (même code, même jar) est promue de test à prod sans être reconstruite. Seul `IMAGE_TAG` identifie le stade de promotion.

---

## Déclencher et suivre la pipeline

### Déclenchement automatique

| Événement | Comportement |
|---|---|
| `git push` sur `test`, `preprod` ou `prod` | Build → Tests → Analyse SonarCloud → Build image Docker → Push Docker Hub → Déploiement sur le VPS |
| Ouverture / mise à jour d'une **Pull Request** vers `test`, `preprod` ou `prod` | Build → Tests → Analyse SonarCloud (mode PR, rapport sur la PR) — **aucun déploiement ni push d'image** |

### Suivre l'exécution

1. Sur GitHub, aller dans l'onglet **Actions** du dépôt.
2. Sélectionner le run correspondant au dernier push/PR.
3. Chaque étape de la pipeline apparaît comme un job distinct et nommé :
    - **1. Build & Test**
    - **2. Analyse de code**
    - **3-4. Dockerisation & Registry**
    - **5. Déploiement**
    - **6. Notification**
4. Un clic sur un job affiche le détail des logs de chaque étape.
5. Le job **6. Notification** affiche un résumé récapitulatif (statuts + lien direct vers l'application déployée) directement dans l'onglet **Summary** de la page du run.

### Consulter les résultats d'analyse SonarCloud

Résultats disponibles sur `https://sonarcloud.io/project/overview?id=bricengueti_Zero-to-deploy` — un sélecteur de branche permet de consulter séparément les résultats de `test`, `preprod`, `prod`, ou d'une Pull Request.

### Vérifier le déploiement manuellement

```bash
ssh cicd@<IP_DU_VPS>
docker ps                          # vérifie que le conteneur est "healthy"
docker compose logs -f             # suit les logs applicatifs en direct
curl http://localhost:<HOST_PORT>/actuator/health
```

Environnements déployés :

- Test : [http://164.132.99.131:3000/](http://164.132.99.131:3000/)
- Preprod : [http://164.132.99.131:3001/](http://164.132.99.131:3001/)
- Prod : [http://164.132.99.131:3002/](http://164.132.99.131:3002/)

### Forcer un redéploiement sans nouveau commit

Depuis l'onglet **Actions**, sélectionner le dernier run réussi sur la branche voulue, puis cliquer sur **Re-run all jobs**.

---

## Scénarios de test

### Tests unitaires (exécutés automatiquement au Stage 1)

| Classe | Scénario testé | Ce qui est vérifié |
|---|---|---|
| `HomeControllerTest` | Le contrôleur retourne la bonne vue | `hello()` renvoie le nom de vue `"hello"` |
| `HomeControllerTest` | L'environnement est transmis au template | `model.getAttribute("environment")` correspond à la valeur injectée (ex. `"PROD"`) |
| `HomeControllerWebMvcTest` | Rendu HTTP complet avec Thymeleaf | Une requête `GET /` simulée retourne `200 OK`, la vue `hello`, l'attribut `environment=PREPROD`, et le HTML rendu contient bien la chaîne `"PREPROD"` |
| `ZeroToDeployApplicationProfileTest` | Chargement correct du profil Spring | Avec `@ActiveProfiles("prod")`, la propriété `app.environment` résolue vaut bien `"PROD"` (donc `application-prod.properties` est le fichier réellement chargé) |

Exécuter uniquement les tests en local :

```bash
./mvnw test
```

Rapport détaillé (succès/échecs par classe) dans `target/surefire-reports/`.

### Scénarios de validation de la pipeline CI/CD

Ces scénarios permettent de vérifier que chaque stage de la pipeline se comporte comme attendu. À exécuter au moins une fois après toute modification du workflow.

| # | Scénario | Déclencheur | Résultat attendu |
|---|---|---|---|
| 1 | Push normal sur `test` | `git push origin test` | Les 6 stages s'exécutent et se terminent en succès ; le conteneur `zero-to-deploy-test` est `(healthy)` sur le VPS |
| 2 | Push normal sur `preprod` | `git push origin preprod` | Idem, déploiement isolé dans `/home/cicd/zero-to-deploy/preprod`, port `3001`, aucun impact sur `test` |
| 3 | Push normal sur `prod` | `git push origin prod` | Idem, déploiement isolé dans `/home/cicd/zero-to-deploy/prod`, port `3002` |
| 4 | Ouverture d'une Pull Request vers `test`/`preprod`/`prod` | Créer une PR | Stages 1 et 2 s'exécutent (build, tests, analyse SonarCloud en mode PR) ; **aucune image n'est buildée/poussée, aucun déploiement n'a lieu** (jobs 3 à 5 ignorés) |
| 5 | Mise à jour d'une PR ouverte | Nouveau commit poussé sur la branche de la PR | La pipeline se relance automatiquement (event `synchronize`), nouveau rapport SonarCloud sur la même PR |
| 6 | Échec d'un test unitaire | Casser volontairement une assertion dans `HomeControllerTest`, puis push | Stage 1 échoue ; stages 2 à 6 ne se déclenchent jamais (`needs:`) ; aucune image poussée, aucun déploiement |
| 7 | Échec du Quality Gate SonarCloud | Introduire un problème de qualité détecté par Sonar (ex. code dupliqué important) | Stage 2 remonte l'échec (visible sur SonarCloud et dans les logs), mais grâce à `continue-on-error: true`, la pipeline continue jusqu'au déploiement — comportement volontaire, à surveiller manuellement sur le dashboard SonarCloud plutôt que bloquant |
| 8 | Redéploiement sans nouveau code | Onglet Actions → dernier run réussi → *Re-run all jobs* | Nouveau `docker pull` de la même image + `docker compose up -d`, conteneur redémarré, healthcheck repasse au vert |
| 9 | Vérification de l'isolation des environnements | Déployer `test` puis `preprod` puis `prod` à la suite | Les 3 conteneurs tournent simultanément sur le VPS (`docker ps`), sur des ports différents, sans conflit ni écrasement mutuel |
| 10 | Vérification du healthcheck externe | Couper temporairement l'application (`docker compose stop`) puis relancer un déploiement | Le step *Vérification du déploiement* retente pendant 200s (20 × 10s) avant d'échouer si l'app ne répond pas ; succès dès que `/actuator/health` répond `200` |
| 11 | Nettoyage ciblé des images | Déployer une nouvelle version deux fois de suite sur le même environnement | Seules les anciennes images *dangling* du dépôt `IMAGE_NAME` sont supprimées ; les images des autres services du VPS (`gateway-service`, `auth-service`, etc.) restent intactes |

### Vérification visuelle manuelle (smoke test)

Après chaque déploiement, contrôle rapide dans le navigateur :

| Environnement | URL | Badge attendu |
|---|---|---|
| Test | [http://164.132.99.131:3000/](http://164.132.99.131:3000/) | Badge bleu **TEST** |
| Preprod | [http://164.132.99.131:3001/](http://164.132.99.131:3001/) | Badge orange **PREPROD** |
| Prod | [http://164.132.99.131:3002/](http://164.132.99.131:3002/) | Badge rouge **PROD** |

Un badge de la mauvaise couleur ou le mauvais texte indique généralement une variable `ENVIRONMENT` mal configurée dans le GitHub Environment correspondant.

---

## Développement local

```bash
# Lancer les tests
./mvnw test

# Lancer l'application en local (profil test par défaut)
./mvnw spring-boot:run

# Construire et lancer via Docker Compose (environnement test)
docker compose --env-file .env.test up -d --build

# Arrêter et nettoyer
docker compose --env-file .env.test down
```

L'application est alors accessible sur `http://localhost:3000` (ou le port défini dans `.env.test`), avec `http://localhost:3000/actuator/health` pour vérifier son état.

Copier `.env.example` vers `.env.test` / `.env.preprod` / `.env.prod` pour tester localement — ces fichiers ne doivent **jamais** être commités (voir `.gitignore`).

---

## Structure du dépôt

```
.
├── src/
│   ├── main/java/TNB/Zero_to_Deploy/
│   │   ├── ZeroToDeployApplication.java
│   │   └── controller/HomeController.java
│   ├── main/resources/
│   │   ├── application.properties
│   │   ├── application-test.properties
│   │   ├── application-preprod.properties
│   │   ├── application-prod.properties
│   │   └── templates/hello.html
│   └── test/java/TNB/Zero_to_Deploy/
│       ├── controller/HomeControllerTest.java
│       ├── controller/HomeControllerWebMvcTest.java
│       └── ZeroToDeployApplicationProfileTest.java
├── .github/workflows/
│   └── deploy.yml              # pipeline CI/CD complete
├── Dockerfile                  # build multi-stage
├── docker-compose.yml
├── .env.example                 # modele, a copier en .env.test/.env.preprod/.env.prod
├── .dockerignore
├── .gitignore
├── init-server.sh               # preparation du VPS (execution unique, manuelle)
├── mvnw / mvnw.cmd / .mvn/       # Maven Wrapper
└── pom.xml
```