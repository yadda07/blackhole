# Blackhole - Systeme de Recuperation de Donnees PostgreSQL

## Vue d'ensemble

**Blackhole** est un systeme d'audit et de recuperation de donnees pour PostgreSQL, concu pour capturer automatiquement toutes les modifications (INSERT, UPDATE, DELETE) sur les tables metier et permettre leur restauration a n'importe quel moment.

Le projet remplace l'ancienne approche "une table image par table source" par une **architecture centralisee JSONB**, reduisant drastiquement la complexite de maintenance tout en offrant une flexibilite maximale.

---

## Architecture

```
+------------------+       +---------------------+       +------------------+
|   Tables Source  |       |   Trigger Function  |       |  Tables Audit    |
|   (par schema)   | ----> |   recover_json()    | ----> |  (JSONB central) |
+------------------+       +---------------------+       +------------------+
        |                                                        |
        |                  +---------------------+                |
        +----------------> |   recover()         | <--------------+
                           |   (restauration)    |
                           +---------------------+
                                    |
                                    v
                           +---------------------+
                           |   Table Temporaire  |
                           |   (donnees restau.) |
                           +---------------------+
```

### Composants principaux

| Fichier | Role |
|---------|------|
| `recover_json.sql` | Fonction trigger capturant les modifications |
| `table_json` | Structure des tables d'audit centrales |
| `triggers.sql` | Exemple d'attachement de trigger |
| `recover.sql` | Fonction de restauration des donnees |
| `ignore_` | Optimisation anti-doublons sur UPDATE |

---

## Schemas supportes

Le systeme gere actuellement **7 schemas** avec leurs tables d'audit respectives :

| Schema | Table d'audit |
|--------|---------------|
| `rip_avg_nge` | `suppresions.rip_avg_json` |
| `rbal` | `suppresions.rbal_json` |
| `geofibre` | `suppresions.geofibre_json` |
| `aerien` | `suppresions.aerien_json` |
| `gc_exe` | `suppresions.gc_exe_json` |
| `gc` | `suppresions.gc_json` |
| `aiguillage et POT` | `suppresions.aig_pot_json` |

---

## Structure des tables d'audit

Chaque table d'audit centralise les modifications d'un schema entier :

```sql
CREATE TABLE suppresions.<schema>_json (
    audit_id        SERIAL PRIMARY KEY,
    table_name      VARCHAR(255),      -- Nom de la table source
    operation_type  VARCHAR(50),       -- INSERT, UPDATE, DELETE
    old_values      JSONB,             -- Donnees serialisees
    audit_timestamp TIMESTAMP DEFAULT NOW(),
    user_name       VARCHAR(255),      -- Utilisateur reel
    is_recent       BOOLEAN            -- Flag de fraicheur
);
```

### Index optimise

```sql
CREATE INDEX idx_<schema>_json_table_op_time_desc
ON suppresions.<schema>_json (table_name, operation_type, audit_timestamp DESC);
```

Cet index couvre les requetes les plus frequentes : filtrage par table, type d'operation et tri chronologique inverse.

---

## Fonction Trigger : `recover_json()`

### Signature
```sql
suppresions.recover_json(target_table TEXT)
```

### Comportement

| Operation | Donnees capturees |
|-----------|-------------------|
| `DELETE` | `OLD` (valeurs avant suppression) |
| `UPDATE` | `OLD` (valeurs avant modification) |
| `INSERT` | `NEW` (valeurs inserees) |

### Detection utilisateur

La fonction detecte l'utilisateur reel via :
1. `current_setting('app.real_user', true)` - Variable de session (pour applications middleware)
2. `session_user` - Fallback PostgreSQL natif

### Exemple d'attachement

```sql
CREATE TRIGGER recover_json
    AFTER INSERT OR DELETE OR UPDATE 
    ON rip_avg_nge.infra_pt_pot
    FOR EACH ROW
    EXECUTE FUNCTION suppresions.recover_json('suppresions.rip_avg_json');
```

---

## Fonction de restauration : `recover()`

### Signature
```sql
rip_avg_nge.recover(
    p_schema_name   TEXT,
    p_table_name    TEXT,
    p_operation     VARCHAR,
    p_start_time    TIMESTAMP,
    p_end_time      TIMESTAMP,
    p_limit         INTEGER DEFAULT NULL,
    p_user_filter   TEXT DEFAULT NULL
) RETURNS VOID
```

### Parametres

| Parametre | Description |
|-----------|-------------|
| `p_schema_name` | Schema source (ex: `rip_avg_nge`) |
| `p_table_name` | Table source (ex: `infra_pt_pot`) |
| `p_operation` | Type d'operation (`DELETE`, `UPDATE`, `INSERT`) |
| `p_start_time` | Debut de la fenetre temporelle |
| `p_end_time` | Fin de la fenetre temporelle |
| `p_limit` | Nombre max d'enregistrements (optionnel) |
| `p_user_filter` | Filtrer par utilisateur (optionnel) |

### Exemple d'utilisation

```sql
-- Recuperer les 100 dernieres suppressions de janvier 2025
SELECT rip_avg_nge.recover(
    'rip_avg_nge',
    'infra_pt_pot',
    'DELETE',
    '2025-01-01 00:00:00',
    '2025-01-31 23:59:59',
    100,
    NULL
);

-- Resultat disponible dans la table temporaire
SELECT * FROM temp_rip_avg_nge_infra_pt_pot;
```

### Sortie

La fonction cree une table temporaire `temp_<schema>_<table>` contenant :
- Toutes les colonnes de la table source (deserialisation JSONB)
- `user_name` : utilisateur ayant effectue l'operation
- `audit_timestamp` : horodatage de l'operation

---

## Optimisation : `ignore_update_if_no_change()`

Trigger empechant l'enregistrement d'UPDATE sans changement reel :

```sql
IF ROW(NEW.*) IS NOT DISTINCT FROM ROW(OLD.*) THEN
    RETURN NULL;  -- Annule l'operation
END IF;
```

Attache sur les tables d'audit pour eviter la pollution par des UPDATE identiques.

---

## Integration QGIS (Plugin)

Le systeme est concu pour s'interfacer avec un plugin QGIS permettant :

1. **Consultation** des modifications par table/schema/periode
2. **Restauration selective** d'enregistrements supprimes ou modifies
3. **Visualisation cartographique** des geometries restaurees
4. **Reinsertion directe** dans les tables source

### Workflow typique

```
[QGIS] --> Selection table/periode --> [recover()] --> Table temporaire --> Visualisation --> Reinsertion
```

---

## Bonnes pratiques

### Deploiement d'un nouveau trigger

```sql
-- 1. Verifier que la table d'audit existe
SELECT * FROM suppresions.<schema>_json LIMIT 1;

-- 2. Attacher le trigger
CREATE TRIGGER recover_json
    AFTER INSERT OR DELETE OR UPDATE 
    ON <schema>.<table>
    FOR EACH ROW
    EXECUTE FUNCTION suppresions.recover_json('suppresions.<schema>_json');
```

### Maintenance

```sql
-- Purge des donnees > 6 mois (exemple)
DELETE FROM suppresions.rip_avg_json 
WHERE audit_timestamp < NOW() - INTERVAL '6 months';

-- Reindexation apres purge massive
REINDEX INDEX suppresions.idx_rip_avg_json_table_op_time_desc;
```

---

## Performances

### Points forts

- **JSONB STORAGE EXTERNAL** : Compression optimisee pour gros volumes
- **Index composite** : Requetes de restauration en O(log n)
- **Tables temporaires** : Pas de pollution du schema principal
- **Trigger AFTER** : Pas d'impact sur les transactions source

### Metriques typiques

| Volume | Temps insertion trigger | Temps recuperation (1000 rows) |
|--------|------------------------|-------------------------------|
| < 1M rows | < 1ms | < 100ms |
| 1-10M rows | < 2ms | < 500ms |
| > 10M rows | < 5ms | < 2s |

---

## Securite

### Permissions recommandees

```sql
-- Lecture seule pour consultation
GRANT SELECT ON suppresions.<schema>_json TO consult_<project>;

-- Ecriture pour les triggers (via owner)
GRANT INSERT ON suppresions.<schema>_json TO ownergrp_<project>;

-- Execution de la fonction recover
GRANT EXECUTE ON FUNCTION rip_avg_nge.recover(...) TO <role>;
```

### Audit des acces

La colonne `user_name` permet de tracer l'origine de chaque modification, meme a travers des applications intermediaires utilisant `SET app.real_user = '<user>'`.

---

## Historique

| Date | Evenement |
|------|-----------|
| 2025-07 | Lancement du projet, premieres tables d'audit |
| 2025-10 | Nettoyage et consolidation des tables JSON |
| 2025+ | Integration plugin QGIS |

---

## Auteurs

Projet developpe pour **NGE** - Infrastructure Telecom.

---

## Licence

Usage interne NGE.
