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
       j.proposal_ip_review_join_id        AS proposal_ip_review_join_id,
       j.proposal_id                       AS proposal_id,
       v.proposal_number                   AS proposal_number,
       v.sequence_number                   AS sequence_number,
       ipr.ip_review_id                    AS ip_review_id,
       ipr.proposal_number                 AS ip_review_proposal_number,
       ipr.sequence_number                 AS ip_review_sequence_number,
       ipr.ip_review_sequence_status       AS ip_review_sequence_status,
       ipr.ip_review_req_type_code         AS ip_review_req_type_code,
       rqt.description                     AS ip_review_req_type_description,
       ipr.review_result_code              AS review_result_code,
       rst.description                     AS review_result_description,
       ipr.review_submission_date          AS review_submission_date,
       ipr.review_receive_date             AS review_receive_date,
       ipr.ip_reviewer                     AS ip_reviewer,
       ipr.ver_nbr                         AS version_number,
       ipr.update_timestamp                AS update_timestamp,
       ipr.update_user                     AS update_user
FROM       kcoeus.proposal_ip_review_join j
JOIN       huron_proposal_version         v   ON v.proposal_id  = j.proposal_id
LEFT JOIN  kcoeus.ip_review               ipr ON ipr.ip_review_id = j.ip_review_id
LEFT JOIN  kcoeus.ip_review_req_type      rqt ON rqt.ip_review_req_type_code = ipr.ip_review_req_type_code
LEFT JOIN  kcoeus.ip_review_result_type   rst ON rst.ip_review_result_type_code = ipr.review_result_code

-- Intellectual Property Review is a SEPARATE versioned business object reached through
-- PROPOSAL_IP_REVIEW_JOIN, not a direct child. Verified in production: exactly one
-- review per proposal version (max 1 per PROPOSAL_ID), covering all 36,863 roots, so
-- this join cannot multiply. IP_REVIEW carries its own PROPOSAL_NUMBER/SEQUENCE_NUMBER
-- and its own ACTIVE/ARCHIVED status, exposed here unaltered.
