WITH huron_award_version AS (
    SELECT award_id, award_number, sequence_number, selection_rule
    FROM (
        SELECT a.award_id,
               a.award_number,
               a.sequence_number,
               CASE WHEN a.award_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY a.award_number
                   ORDER BY CASE WHEN a.award_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            a.sequence_number DESC,
                            a.award_id        DESC
               ) AS rn
        FROM   kcoeus.award a
    )
    WHERE rn = 1
)
SELECT
       ucs.apu_credit_split_id             AS apu_credit_split_id,
       ucs.award_person_unit_id            AS award_person_unit_id,
       pu.award_person_id                  AS award_person_id,
       p.award_id                          AS award_id,
       p.award_number                      AS award_number,
       p.sequence_number                   AS sequence_number,
       p.person_id                         AS person_id,
       pu.unit_number                      AS unit_number,
       un.unit_name                        AS unit_name,
       ucs.inv_credit_type_code            AS inv_credit_type_code,
       ict.description                     AS inv_credit_type_description,
       ucs.credit                          AS credit_percentage,
       ucs.ver_nbr                         AS version_number,
       ucs.update_timestamp                AS update_timestamp,
       ucs.update_user                     AS update_user
FROM       kcoeus.award_pers_unit_cred_splits ucs
JOIN       kcoeus.award_person_units pu ON pu.award_person_unit_id = ucs.award_person_unit_id
JOIN       kcoeus.award_persons      p  ON p.award_person_id       = pu.award_person_id
JOIN       huron_award_version       v  ON v.award_id              = p.award_id
LEFT JOIN  kcoeus.unit               un ON un.unit_number          = pu.unit_number
LEFT JOIN  kcoeus.inv_credit_type    ict ON ict.inv_credit_type_code = ucs.inv_credit_type_code

-- Third level of the personnel graph: award -> person -> person unit -> credit split.
-- Keys on AWARD_PERSON_UNIT_ID; award keys are supplied by walking back up through
-- AWARD_PERSON_UNITS and AWARD_PERSONS (both many:1, so no multiplication).
