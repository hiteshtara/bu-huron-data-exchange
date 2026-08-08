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
       ai.subaward_amount_info_id          AS subaward_amount_info_id,
       ai.subaward_id                      AS subaward_id,
       ai.subaward_code                    AS subaward_code,
       ai.sequence_number                  AS sequence_number,
       ai.modification_number              AS modification_number,
       ai.modification_type_code           AS modification_type_code,
       mt.description                      AS modification_type_description,
       ai.modification_effective_date      AS modification_effective_date,
       ai.effective_date                   AS effective_date,
       ai.obligated_amount                 AS obligated_amount,
       ai.obligated_change                 AS obligated_change,
       ai.obligated_change_direct          AS obligated_change_direct,
       ai.obligated_change_indirect        AS obligated_change_indirect,
       ai.anticipated_amount               AS anticipated_amount,
       ai.anticipated_change               AS anticipated_change,
       ai.anticipated_change_direct        AS anticipated_change_direct,
       ai.anticipated_change_indirect      AS anticipated_change_indirect,
       ai.rate                             AS rate,
       ai.performance_start_date           AS performance_start_date,
       ai.performance_end_date             AS performance_end_date,
       ai.purchase_order_num               AS purchase_order_number,
       DBMS_LOB.SUBSTR(ai.comments, 2000, 1) AS comments,
       ai.ver_nbr                          AS version_number,
       ai.update_timestamp                 AS update_timestamp,
       ai.update_user                      AS update_user
FROM       kcoeus.subaward_amount_info ai
JOIN       huron_subaward_version v ON v.subaward_id = ai.subaward_id
LEFT JOIN  kcoeus.subaward_modification_type mt ON mt.code = ai.modification_type_code

-- Money history, one row per modification. These are transactions, not a current
-- balance: each row records the obligated/anticipated change made by one modification,
-- with its own effective and performance dates. We kept it as a child collection so
-- the history stays intact -- 10,761 rows across the 3,466 current subawards.
