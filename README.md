# Historiques des requêtes dans une BDD Postres

Création d'un schéma audits contenant 2 tables :
- tables_monitorees : Liste des tables dont on veut sauvegarder l'historique des requêtes effectuées (insert update et/ou delete)
- historiques : Détails des opérations effectuées sur les tables monitorées
