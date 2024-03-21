# Historiques des requêtes dans une BDD Postres

Création d'un schéma audits contenant 2 tables :
- 'tables_monitorees' : Liste des tables dont on veut sauvegarder l'historique des requêtes effectuées (insert update et/ou delete)
- 'historiques' : Détails des opérations effectuées sur les tables monitorées  
<br>
### Gestion du champ 'user_operation'
La table 'historiques' contient un champ 'user_operation' qui contient la valeur de current_user dans Postgres.
Pour pouvoir surcharger l'utilisateur Postgres, il est possible :

1/ De définir une variable 'myapp.username' en recompilant une image Postgres :
```
FROM postgres:16.2
RUN echo "myapp.username = 'null'" >> /usr/share/postgresql/postgresql.conf.sample
```
2/ De créer une procédure mettant à jour cette variable (Utiliser SET LOCAL pour utiliser la valeur définie uniquement pour la transaction en cours)
```
CREATE FUNCTION audits.set_username(username text) RETURNS void AS $$
BEGIN
	SET LOCAL myapp.username = username;
END;
$$ LANGUAGE 'plpgsql';
```
3/ Appeler cette procédure lors d'events before_(insert/update/delete) en lui fournissant une adresse mail provenant par exemple de Keycloak 
