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
       ar.subaward_amt_released_id         AS subaward_amt_released_id,
       ar.subaward_id                      AS subaward_id,
       ar.subaward_code                    AS subaward_code,
       ar.sequence_number                  AS sequence_number,
       ar.amount_released                  AS amount_released,
       ar.effective_date                   AS effective_date,
       ar.invoice_number                   AS invoice_number,
       ar.invoice_status                   AS invoice_status,
       ar.start_date                       AS start_date,
       ar.end_date                         AS end_date,
       DBMS_LOB.SUBSTR(ar.comments, 2000, 1) AS comments,
       ar.created_by                       AS created_by,
       ar.created_date                     AS created_date,
       ar.ver_nbr                          AS version_number,
       ar.update_timestamp                 AS update_timestamp,
       ar.update_user                      AS update_user
FROM       kcoeus.subaward_amt_released ar
JOIN       huron_subaward_version v ON v.subaward_id = ar.subaward_id

-- Invoice / amount-released history. BU has barely used this: the whole table holds
-- 2 rows, and neither belongs to a current subaward, so this query returns nothing
-- today. We kept it because the structure is part of the Subaward model and a mapper
-- benefits from knowing it exists.
