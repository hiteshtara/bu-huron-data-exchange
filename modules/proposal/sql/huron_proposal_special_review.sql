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
       sr.proposal_special_review_id       AS proposal_special_review_id,
       sr.proposal_id                      AS proposal_id,
       p.proposal_number                   AS proposal_number,
       p.sequence_number                   AS sequence_number,
       sr.special_review_number            AS special_review_number,
       sr.special_review_code              AS special_review_code,
       srt.description                     AS special_review_description,
       sr.approval_type_code               AS approval_type_code,
       apt.description                     AS approval_type_description,
       sr.protocol_number                  AS protocol_number,
       sr.application_date                 AS application_date,
       sr.approval_date                    AS approval_date,
       sr.expiration_date                  AS expiration_date,
       sr.comments                         AS comments,
       sr.ver_nbr                          AS version_number,
       sr.update_timestamp                 AS update_timestamp,
       sr.update_user                      AS update_user
FROM       kcoeus.proposal_special_review sr
JOIN       kcoeus.proposal             p   ON p.proposal_id = sr.proposal_id
JOIN       huron_proposal_version      v   ON v.proposal_id = sr.proposal_id
LEFT JOIN  kcoeus.special_review       srt ON srt.special_review_code = sr.special_review_code
LEFT JOIN  kcoeus.sp_rev_approval_type apt ON apt.approval_type_code  = sr.approval_type_code

-- PROPOSAL_SPECIAL_REVIEW carries only PROPOSAL_ID; PROPOSAL is joined many:1 for the
-- business keys. PROTOCOL_NUMBER is the lineage link to the IRB/IACUC module.
