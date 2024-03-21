-----------
-- Reset --
-----------
DROP TRIGGER IF EXISTS tr_gestion_tables_monitorees ON audits.tables_monitorees;
DROP FUNCTION IF EXISTS audits.ps_make_historique() CASCADE;
DROP FUNCTION IF EXISTS audits.ps_gestion_tables_monitorees() CASCADE;
DROP TABLE IF EXISTS audits.historiques;
DROP TABLE IF EXISTS audits.tables_monitorees;


-------------------------------------
-- Table d'accueil des historiques --
-------------------------------------

-- Création du schéma
CREATE SCHEMA IF NOT EXISTS audits;

-- Table
CREATE TABLE audits.historiques (
	id serial NOT NULL,
	date_operation TIMESTAMP DEFAULT NOW(),
	user_operation TEXT DEFAULT CURRENT_USER,
	schema_name TEXT NOT NULL,
	table_name TEXT NOT NULL,
	operation TEXT NOT NULL,
	old_value JSONB DEFAULT NULL,
	new_value JSONB DEFAULT NULL,
	CONSTRAINT historiques_pk PRIMARY KEY (id)
);
COMMENT ON TABLE audits.historiques IS 'Historiques des requêtes sur les tables monitorées';

-- Function trigger
CREATE FUNCTION audits.ps_make_historique() RETURNS trigger AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
        INSERT INTO audits.historiques(user_operation, schema_name, table_name, operation, old_value)
        VALUES (COALESCE(NULLIF(current_setting('myapp.username'), 'null'), CURRENT_USER), TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, to_jsonb(OLD));
        RETURN old;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audits.historiques(user_operation, schema_name, table_name, operation, old_value, new_value)
        VALUES (COALESCE(NULLIF(current_setting('myapp.username'), 'null'), CURRENT_USER), TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN new;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audits.historiques(user_operation, schema_name, table_name, operation, new_value)
        VALUES (COALESCE(NULLIF(current_setting('myapp.username'), 'null'), CURRENT_USER), TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, to_jsonb(NEW));
        RETURN new;
    END IF;
END;
$$ LANGUAGE 'plpgsql';


--------------------------------------------
-- Table de gestion des tables monitorées --
--------------------------------------------

-- Table
CREATE TABLE audits.tables_monitorees (
	id serial,
	schema_name TEXT NOT NULL,
	table_name TEXT NOT NULL,
	check_insert BOOL NOT NULL DEFAULT TRUE,
	check_update BOOL NOT NULL DEFAULT TRUE,
	check_delete BOOL NOT NULL DEFAULT TRUE,
	CONSTRAINT tables_monitorees_pk PRIMARY KEY (id),
	CONSTRAINT tables_monitorees_un UNIQUE (schema_name,table_name)
);
COMMENT ON TABLE audits.tables_monitorees IS 'Liste des tables pour lesquelles on enregistre l''historique des requêtes (INSERT UPDATE DELETE)';

-- Function trigger
CREATE FUNCTION audits.ps_gestion_tables_monitorees() RETURNS trigger AS $$
DECLARE
	command TEXT; 
BEGIN
	IF TG_OP = 'DELETE' THEN
		command := 'DROP TRIGGER tr_make_historique_insert ON ' || OLD.schema_name || '.' || OLD.table_name || ';'
				|| 'DROP TRIGGER tr_make_historique_update ON ' || OLD.schema_name || '.' || OLD.table_name || ';'
				|| 'DROP TRIGGERtr_make_historique_delete ON ' || OLD.schema_name || '.' || OLD.table_name || ';';
		EXECUTE command;
    ELSIF TG_OP = 'INSERT' THEN
	    command := '';
    	IF NEW.check_insert IS TRUE THEN
	    	command := command || 'CREATE TRIGGER tr_make_historique_insert BEFORE INSERT ON ' || NEW.schema_name || '.' || NEW.table_name || ' FOR EACH ROW EXECUTE PROCEDURE audits.ps_make_historique();';
		END IF;
    	IF NEW.check_update IS TRUE THEN
	    	command := command || 'CREATE TRIGGER tr_make_historique_update BEFORE UPDATE ON ' || NEW.schema_name || '.' || NEW.table_name || ' FOR EACH ROW EXECUTE PROCEDURE audits.ps_make_historique();';
		END IF;
    	IF NEW.check_delete IS TRUE THEN
	    	command := command || 'CREATE TRIGGER tr_make_historique_delete BEFORE DELETE ON ' || NEW.schema_name || '.' || NEW.table_name || ' FOR EACH ROW EXECUTE PROCEDURE audits.ps_make_historique();';
		END IF;
    	EXECUTE command;
    ELSIF TG_OP = 'UPDATE' THEN
    	command := '';
    	IF NEW.check_insert IS TRUE AND OLD.check_insert IS FALSE THEN
    	-- Update check_insert
	    	command := command || 'CREATE TRIGGER tr_make_historique_insert BEFORE INSERT ON ' || NEW.schema_name || '.' || NEW.table_name || ' FOR EACH ROW EXECUTE PROCEDURE audits.ps_make_historique();';
	    ELSIF NEW.check_insert IS FALSE AND OLD.check_insert IS TRUE THEN
	    	command := command || 'DROP TRIGGER tr_make_historique_insert ON ' || OLD.schema_name || '.' || OLD.table_name || ';';
		END IF;
    	-- Update check_update
    	IF NEW.check_update IS TRUE AND OLD.check_update IS FALSE THEN    	
	    	command := command || 'CREATE TRIGGER tr_make_historique_update BEFORE UPDATE ON ' || NEW.schema_name || '.' || NEW.table_name || ' FOR EACH ROW EXECUTE PROCEDURE audits.ps_make_historique();';
	    ELSIF NEW.check_update IS FALSE AND OLD.check_update IS TRUE THEN
	    	command := command || 'DROP TRIGGER tr_make_historique_update ON ' || OLD.schema_name || '.' || OLD.table_name || ';';
		END IF;
    	-- Update check_delete
	   	IF NEW.check_delete IS TRUE AND OLD.check_delete IS FALSE THEN
	    	command := command || 'CREATE TRIGGER tr_make_historique_delete BEFORE DELETE ON ' || NEW.schema_name || '.' || NEW.table_name || ' FOR EACH ROW EXECUTE PROCEDURE audits.ps_make_historique();';
	    ELSIF NEW.check_delete IS FALSE AND OLD.check_delete IS TRUE THEN
	    	command := command || 'DROP TRIGGER tr_make_historique_delete ON ' || OLD.schema_name || '.' || OLD.table_name || ';';
		END IF;
    	EXECUTE command;
	END IF;
	RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';

-- Trigger
CREATE TRIGGER tr_gestion_tables_monitorees AFTER INSERT OR UPDATE OR DELETE ON audits.tables_monitorees
FOR EACH ROW EXECUTE PROCEDURE audits.ps_gestion_tables_monitorees();
