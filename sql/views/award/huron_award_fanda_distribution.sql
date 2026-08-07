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
       d.award_amt_fna_distribution_id     AS award_amt_fna_distribution_id,
       d.award_id                          AS award_id,
       d.award_number                      AS award_number,
       d.sequence_number                   AS sequence_number,
       d.award_amount_info_id              AS award_amount_info_id,
       d.amount_sequence_number            AS amount_sequence_number,
       d.budget_period                     AS budget_period,
       d.start_date                        AS start_date,
       d.end_date                          AS end_date,
       d.direct_cost                       AS direct_cost,
       d.indirect_cost                     AS indirect_cost,
       d.ver_nbr                           AS version_number,
       d.update_timestamp                  AS update_timestamp,
       d.update_user                       AS update_user
FROM       kcoeus.award_amt_fna_distribution d
JOIN       huron_award_version v ON v.award_id = d.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
