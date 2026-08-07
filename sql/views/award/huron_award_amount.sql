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
       ai.award_amount_info_id             AS award_amount_info_id,
       ai.award_id                         AS award_id,
       ai.award_number                     AS award_number,
       ai.sequence_number                  AS sequence_number,
       ai.transaction_id                   AS transaction_id,
       ai.tnm_document_number              AS time_and_money_document_number,
       ai.originating_award_version        AS originating_award_version,
       ai.entry_type                       AS entry_type,
       ai.anticipated_total_amount         AS anticipated_total_amount,
       ai.anticipated_total_direct         AS anticipated_total_direct,
       ai.anticipated_total_indirect       AS anticipated_total_indirect,
       ai.anticipated_change               AS anticipated_change,
       ai.anticipated_change_direct        AS anticipated_change_direct,
       ai.anticipated_change_indirect      AS anticipated_change_indirect,
       ai.ant_distributable_amount         AS anticipated_distributable_amount,
       ai.amount_obligated_to_date         AS amount_obligated_to_date,
       ai.obligated_total_direct           AS obligated_total_direct,
       ai.obligated_total_indirect         AS obligated_total_indirect,
       ai.obligated_change                 AS obligated_change,
       ai.obligated_change_direct          AS obligated_change_direct,
       ai.obligated_change_indirect        AS obligated_change_indirect,
       ai.obli_distributable_amount        AS obligated_distributable_amount,
       ai.current_fund_effective_date      AS current_fund_effective_date,
       ai.obligation_expiration_date       AS obligation_expiration_date,
       ai.final_expiration_date            AS final_expiration_date,
       ai.ver_nbr                          AS version_number,
       ai.update_timestamp                 AS update_timestamp,
       ai.update_user                      AS update_user
FROM       kcoeus.award_amount_info ai
JOIN       huron_award_version v ON v.award_id = ai.award_id

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
