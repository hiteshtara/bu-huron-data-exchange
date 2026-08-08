WITH huron_subaward_version AS (
    SELECT subaward_id, subaward_code, sequence_number, selection_rule
    FROM (
        SELECT s.subaward_id,
               s.subaward_code,
               s.sequence_number,
               CASE WHEN s.subaward_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY s.subaward_code
                   ORDER BY CASE WHEN s.subaward_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            s.sequence_number  DESC,
                            s.update_timestamp DESC,
                            s.subaward_id      DESC
               ) AS rn
        FROM   kcoeus.subaward s
    )
    WHERE rn = 1
)
SELECT
       c.subaward_contact_id               AS subaward_contact_id,
       c.subaward_id                       AS subaward_id,
       c.subaward_code                     AS subaward_code,
       c.sequence_number                   AS sequence_number,
       c.contact_type_code                 AS contact_type_code,
       ct.description                      AS contact_type_description,
       c.requisitioner_id                  AS requisitioner_person_id,
       c.rolodex_id                        AS rolodex_id,
       rlx.last_name                       AS rolodex_last_name,
       rlx.first_name                      AS rolodex_first_name,
       rlx.organization                    AS rolodex_organization,
       c.ver_nbr                           AS version_number,
       c.update_timestamp                  AS update_timestamp,
       c.update_user                       AS update_user
FROM       kcoeus.subaward_contact c
JOIN       huron_subaward_version v  ON v.subaward_id = c.subaward_id
LEFT JOIN  kcoeus.contact_type      ct ON ct.contact_type_code = c.contact_type_code
LEFT JOIN  kcoeus.rolodex           rlx ON rlx.rolodex_id      = c.rolodex_id

-- Who is on a subaward. The OJB mapping offers two identities, ROLODEX_ID and
-- REQUISITIONER_ID, but production only uses one: ROLODEX_ID is NULL on all 194,207
-- rows and REQUISITIONER_ID is populated on all of them. The rolodex join is kept
-- because the relationship is real in the model, but it returns nothing today.
--
-- REQUISITIONER_ID is a KIM person id. As on Award, there is no ORM relationship from
-- here to a person table -- KC resolves the name at runtime through KcPersonService --
-- so we expose the id and do not attempt to join a name.
--
-- Note this dataset has no PERSON_ID column at all; SUBAWARD_CONTACT never had one.
