Feature: Déploiement Immich
  En tant qu'administrateur NAS
  Je veux qu'Immich soit opérationnel après provisioning
  Afin de gérer les photos de la famille

  Scenario: Stack Docker démarre correctement
    Given Colima est actif
    When le rôle Immich est appliqué
    Then le container "immich-server" est running
    And le container "immich-postgres" est running
    And le container "immich-redis" est running

  Scenario: API Immich répond
    Given la stack Immich est démarrée
    When je curl GET /api/server/ping
    Then le code HTTP est 200
    And la réponse contient "pong"

  Scenario: Comptes utilisateurs créés
    Given la stack Immich est démarrée
    Then les 8 comptes existent: loic-perso, loic-immo, loic-pro, alban, ilan, mahaut, alice-perso, alice-prof

  Scenario: Album Famille partagé
    Given la stack Immich est démarrée
    Then l'album "Famille" existe
    And l'album "Famille" est partagé avec alban et ilan

  Scenario: Idempotence du rôle
    Given le rôle Immich a déjà été appliqué
    When le rôle Immich est appliqué à nouveau
    Then aucun container n'est redémarré
    And l'API répond toujours
