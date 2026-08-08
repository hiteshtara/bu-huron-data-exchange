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
       fp.award_funding_proposal_id        AS award_funding_proposal_id,
       fp.proposal_id                      AS proposal_id,
       v.proposal_number                   AS proposal_number,
       v.sequence_number                   AS sequence_number,
       fp.award_id                         AS award_id,
       a.award_number                      AS award_number,
       a.sequence_number                   AS award_sequence_number,
       a.title                             AS award_title,
       fp.active                           AS active_flag,
       fp.ver_nbr                          AS version_number,
       fp.update_timestamp                 AS update_timestamp,
       fp.update_user                      AS update_user
FROM       kcoeus.award_funding_proposals fp
JOIN       huron_proposal_version v ON v.proposal_id = fp.proposal_id
LEFT JOIN  kcoeus.award           a ON a.award_id    = fp.award_id

-- The proposal side of the Award <-> Institutional Proposal funding link. The mirror
-- image of modules/award/sql/huron_award_funding_proposal.sql.
