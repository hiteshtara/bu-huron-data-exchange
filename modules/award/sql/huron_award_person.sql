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
       p.award_person_id                   AS award_person_id,
       p.award_id                          AS award_id,
       p.award_number                      AS award_number,
       p.sequence_number                   AS sequence_number,
       /* ---- who the person is: KIM person OR external rolodex contact ---- */
       p.person_id                         AS person_id,
       p.rolodex_id                        AS rolodex_id,
       CASE WHEN p.person_id  IS NOT NULL THEN 'KIM_PERSON'
            WHEN p.rolodex_id IS NOT NULL THEN 'ROLODEX'
            ELSE 'UNIDENTIFIED' END        AS person_source,
       p.full_name                         AS full_name,
       rlx.last_name                       AS rolodex_last_name,
       rlx.first_name                      AS rolodex_first_name,
       rlx.organization                    AS rolodex_organization,
       rlx.email_address                   AS rolodex_email_address,
       /* ---- role ---- */
       p.contact_role_code                 AS contact_role_code,
       rle.description                     AS contact_role_description,
       p.key_person_project_role           AS key_person_project_role,
       p.faculty_flag                      AS faculty_flag,
       /* ---- effort ---- */
       p.academic_year_effort              AS academic_year_effort,
       p.calendar_year_effort              AS calendar_year_effort,
       p.summer_effort                     AS summer_effort,
       p.total_effort                      AS total_effort,
       p.add_credit_split                  AS include_in_credit_allocation,
       p.opt_in_unit_status                AS opt_in_unit_status,
       p.ver_nbr                           AS version_number,
       p.update_timestamp                  AS update_timestamp,
       p.update_user                       AS update_user
FROM       kcoeus.award_persons p
JOIN       huron_award_version v ON v.award_id = p.award_id
LEFT JOIN  kcoeus.rolodex     rlx ON rlx.rolodex_id = p.rolodex_id
LEFT JOIN  kcoeus.eps_prop_person_role rle
       ON  rle.prop_person_role_code  = p.contact_role_code
       AND rle.sponsor_hierarchy_name = 'DEFAULT'

-- Personnel identity has TWO sources, per AwardContact in the KC source:
--   PERSON_ID  -> a KIM person, resolved in Java by KcPersonService. There is no
--                 OJB/JPA reference from AWARD_PERSONS to a person table, so the
--                 name is NOT obtainable by a simple join; KC stores a denormalized
--                 copy in AWARD_PERSONS.FULL_NAME and refreshes it from the person
--                 record on read (AwardContact.getFullName -> getContact()).
--   ROLODEX_ID -> an external contact in ROLODEX, which IS joinable.
-- Production: 345,133 rows carry PERSON_ID, 464 carry ROLODEX_ID, 3 carry neither.
-- PERSON_SOURCE makes that explicit so Huron does not treat FULL_NAME as
-- authoritative for KIM persons.
--
-- CONTACT_ROLE_CODE decodes against EPS_PROP_PERSON_ROLE (KC resolves it through
-- PropAwardPersonRoleService). That table holds TWO rows per code -- one per
-- SPONSOR_HIERARCHY_NAME ('DEFAULT' and 'NIH Multiple PI') -- so an unfiltered join
-- DOUBLES the dataset: 345,600 -> 691,200 rows, verified. The join is therefore
-- pinned to the DEFAULT hierarchy, which resolves all 345,600 rows with 0 unmatched.
-- Awards under the NIH multiple-PI hierarchy carry a different label for the same
-- code; that nuance is reported, not resolved here.
