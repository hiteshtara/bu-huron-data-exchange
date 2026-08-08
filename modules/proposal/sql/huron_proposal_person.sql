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
       pp.proposal_person_id               AS proposal_person_id,
       pp.proposal_id                      AS proposal_id,
       pp.proposal_number                  AS proposal_number,
       pp.sequence_number                  AS sequence_number,
       pp.person_id                        AS person_id,
       pp.rolodex_id                       AS rolodex_id,
       CASE WHEN pp.person_id  IS NOT NULL THEN 'KIM_PERSON'
            WHEN pp.rolodex_id IS NOT NULL THEN 'ROLODEX'
            ELSE 'UNIDENTIFIED' END        AS person_source,
       pp.full_name                        AS full_name,
       rlx.last_name                       AS rolodex_last_name,
       rlx.first_name                      AS rolodex_first_name,
       rlx.organization                    AS rolodex_organization,
       pp.contact_role_code                AS contact_role_code,
       rle.description                     AS contact_role_description,
       pp.key_person_project_role          AS key_person_project_role,
       pp.faculty_flag                     AS faculty_flag,
       pp.academic_year_effort             AS academic_year_effort,
       pp.calendar_year_effort             AS calendar_year_effort,
       pp.summer_effort                    AS summer_effort,
       pp.total_effort                     AS total_effort,
       pp.add_credit_split                 AS include_in_credit_allocation,
       pp.ver_nbr                          AS version_number,
       pp.update_timestamp                 AS update_timestamp,
       pp.update_user                      AS update_user
FROM       kcoeus.proposal_persons pp
JOIN       huron_proposal_version  v   ON v.proposal_id = pp.proposal_id
LEFT JOIN  kcoeus.rolodex          rlx ON rlx.rolodex_id = pp.rolodex_id
LEFT JOIN  kcoeus.eps_prop_person_role rle
       ON  rle.prop_person_role_code  = pp.contact_role_code
       AND rle.sponsor_hierarchy_name = 'DEFAULT'

-- Identity has two sources, as on Award: PERSON_ID is a KIM person resolved in Java by
-- KcPersonService with NO ORM relationship to a person table (146,998 rows), while
-- ROLODEX_ID is joinable (797 rows). FULL_NAME is a persisted denormalized copy.
--
-- CONTACT_ROLE_CODE decodes against EPS_PROP_PERSON_ROLE, which holds TWO rows per code
-- (one per SPONSOR_HIERARCHY_NAME). Unfiltered, that join takes this dataset from
-- 147,795 to 295,590 rows -- verified. Pinned to DEFAULT: 0 unmatched.
