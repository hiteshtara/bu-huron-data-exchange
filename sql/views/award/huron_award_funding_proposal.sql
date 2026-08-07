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
       fp.award_funding_proposal_id        AS award_funding_proposal_id,
       fp.award_id                         AS award_id,
       a.award_number                      AS award_number,
       a.sequence_number                   AS sequence_number,
       fp.proposal_id                      AS proposal_id,
       ip.proposal_number                  AS proposal_number,
       ip.sequence_number                  AS proposal_sequence_number,
       ip.title                            AS proposal_title,
       fp.active                           AS active_flag,
       fp.ver_nbr                          AS version_number,
       fp.update_timestamp                 AS update_timestamp,
       fp.update_user                      AS update_user
FROM       kcoeus.award_funding_proposals fp
JOIN       kcoeus.award    a  ON a.award_id    = fp.award_id
LEFT JOIN  kcoeus.proposal ip ON ip.proposal_id = fp.proposal_id
JOIN       huron_award_version v ON v.award_id = fp.award_id

-- AWARD_FUNDING_PROPOSALS stores only AWARD_ID and PROPOSAL_ID. Both parents are
-- joined many:1 to expose the business keys on each side of the link.

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
