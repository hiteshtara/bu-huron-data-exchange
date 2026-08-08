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
       f.subaward_funding_source_id        AS subaward_funding_source_id,
       f.subaward_id                       AS subaward_id,
       f.subaward_code                     AS subaward_code,
       f.sequence_number                   AS sequence_number,
       /* ---- the Award link, exactly as KC recorded it ------------------- */
       f.award_id                          AS funding_award_id,
       a.award_number                      AS funding_award_number,
       a.sequence_number                   AS funding_award_sequence_number,
       a.award_sequence_status             AS funding_award_sequence_status,
       CASE WHEN cur.award_id IS NOT NULL THEN 'Y' ELSE 'N' END
                                           AS funding_award_version_is_current,
       cur.award_id                        AS current_award_id,
       a.title                             AS funding_award_title,
       a.sponsor_code                      AS funding_award_sponsor_code,
       f.ver_nbr                           AS version_number,
       f.update_timestamp                  AS update_timestamp,
       f.update_user                       AS update_user
FROM       kcoeus.subaward_funding_source f
JOIN       huron_subaward_version v ON v.subaward_id = f.subaward_id
LEFT JOIN  kcoeus.award           a ON a.award_id    = f.award_id
LEFT JOIN  (
        SELECT award_id, award_number FROM (
            SELECT x.award_id, x.award_number,
                   ROW_NUMBER() OVER (PARTITION BY x.award_number
                       ORDER BY CASE WHEN x.award_sequence_status='ACTIVE' THEN 0 ELSE 1 END,
                                x.sequence_number DESC, x.award_id DESC) rn
            FROM kcoeus.award x)
        WHERE rn = 1
) cur ON cur.award_id = f.award_id

-- HOW A SUBAWARD CONNECTS BACK TO AN AWARD
--
-- This is the join Huron needs to attach the Subaward graph to the Award graph.
--
-- SUBAWARD_FUNDING_SOURCE.AWARD_ID points at a specific AWARD ROW -- one award
-- VERSION -- not at the award as a whole. That is deliberate in KC: the link records
-- the award version that existed when the subaward was funded. We checked production
-- and 5,846 of the 7,930 funding rows on current subawards (74%) point at a version
-- that has since been superseded. We kept the link exactly as KC recorded it rather
-- than re-pointing it at the current version, because the recorded version is real
-- history and cannot be recovered once discarded.
--
-- To reach the Award root in modules/award, join on FUNDING_AWARD_NUMBER:
--
--     huron_subaward_funding_source.funding_award_number
--       = huron_award.award_number
--
-- We verified every referenced AWARD_NUMBER resolves to a selected Award root, so no
-- subaward is orphaned by this route. FUNDING_AWARD_VERSION_IS_CURRENT tells you
-- whether the recorded version is still the current one, and CURRENT_AWARD_ID gives
-- the current AWARD_ID where it is.
--
-- 3,431 of 3,466 current subawards have at least one funding source; one subaward has
-- as many as 40. There are no orphan AWARD_ID values.
