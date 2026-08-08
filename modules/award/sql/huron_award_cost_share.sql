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
       cs.award_cost_share_id              AS award_cost_share_id,
       cs.award_id                         AS award_id,
       cs.award_number                     AS award_number,
       cs.sequence_number                  AS sequence_number,
       cs.project_period                   AS project_period,
       cs.cost_share_type_code             AS cost_share_type_code,
       cst.description                     AS cost_share_type_description,
       cs.commitment_amount                AS commitment_amount,
       cs.cost_share_percentage            AS cost_share_percentage,
       cs.cost_share_met                   AS cost_share_met,
       cs.verification_date                AS verification_date,
       cs.source                           AS source_account,
       cs.destination                      AS destination_account,
       cs.unit_number                      AS unit_number,
       un.unit_name                        AS unit_name,
       cs.ver_nbr                          AS version_number,
       cs.update_timestamp                 AS update_timestamp,
       cs.update_user                      AS update_user
FROM       kcoeus.award_cost_share cs
LEFT JOIN  kcoeus.cost_share_type cst ON cst.cost_share_type_code = cs.cost_share_type_code
LEFT JOIN  kcoeus.unit            un  ON un.unit_number           = cs.unit_number
JOIN       huron_award_version v ON v.award_id = cs.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
