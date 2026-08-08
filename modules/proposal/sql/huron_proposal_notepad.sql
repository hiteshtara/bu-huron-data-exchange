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
       np.proposal_notepad_id              AS proposal_notepad_id,
       np.proposal_id                      AS proposal_id,
       np.proposal_number                  AS proposal_number,
       np.entry_number                     AS entry_number,
       np.note_topic                       AS note_topic,
       DBMS_LOB.SUBSTR(np.comments, 4000, 1) AS comments,
       np.restricted_view                  AS restricted_view,
       np.create_timestamp                 AS create_timestamp,
       np.create_user                      AS create_user,
       np.ver_nbr                          AS version_number,
       np.update_timestamp                 AS update_timestamp,
       np.update_user                      AS update_user
FROM       kcoeus.proposal_notepad np
JOIN       huron_proposal_version  v ON v.proposal_id = np.proposal_id

-- PROPOSAL_NOTEPAD has no SEQUENCE_NUMBER column: notes attach to the proposal id.
