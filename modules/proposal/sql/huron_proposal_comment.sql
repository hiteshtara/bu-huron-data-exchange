WITH huron_proposal_version AS (
    SELECT proposal_id, proposal_number, sequence_number, selection_rule
    FROM (
        SELECT p.proposal_id,
               p.proposal_number,
               p.sequence_number,
               CASE WHEN p.proposal_sequence_status = 'ACTIVE'
                    THEN 'ACTIVE_STATUS' ELSE 'MAX_SEQUENCE_FALLBACK' END AS selection_rule,
               ROW_NUMBER() OVER (
                   PARTITION BY p.proposal_number
                   ORDER BY CASE WHEN p.proposal_sequence_status = 'ACTIVE' THEN 0 ELSE 1 END,
                            p.sequence_number DESC,
                            p.proposal_id     DESC
               ) AS rn
        FROM   kcoeus.proposal p
    )
    WHERE rn = 1
)
SELECT
       c.proposal_comments_id              AS proposal_comments_id,
       c.proposal_id                       AS proposal_id,
       c.proposal_number                   AS proposal_number,
       c.sequence_number                   AS sequence_number,
       c.comment_type_code                 AS comment_type_code,
       ct.description                      AS comment_type_description,
       DBMS_LOB.SUBSTR(c.comments, 4000, 1) AS comments,
       c.ver_nbr                           AS version_number,
       c.update_timestamp                  AS update_timestamp,
       c.update_user                       AS update_user
FROM       kcoeus.proposal_comments c
JOIN       huron_proposal_version   v  ON v.proposal_id = c.proposal_id
LEFT JOIN  kcoeus.comment_type      ct ON ct.comment_type_code = c.comment_type_code

-- COMMENTS is a CLOB, truncated to 4000 characters.
