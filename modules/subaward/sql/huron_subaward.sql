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
       s.subaward_id                       AS subaward_id,
       s.subaward_code                     AS subaward_code,
       s.sequence_number                   AS sequence_number,
       s.document_number                   AS document_number,
       v.selection_rule                    AS root_selection_rule,
       s.subaward_sequence_status          AS subaward_sequence_status,
       s.ver_nbr                           AS version_number,
       s.title                             AS title,
       s.status_code                       AS status_code,
       st.description                      AS status_description,
       s.subaward_type_code                AS subaward_type_code,
       at.description                      AS subaward_type_description,
       s.cost_type                         AS cost_type_code,
       ct.description                      AS cost_type_description,
       s.organization_id                   AS organization_id,
       o.organization_name                 AS organization_name,
       s.vendor_number                     AS vendor_number,
       s.requisitioner_id                  AS requisitioner_id,
       s.requisitioner_unit                AS requisitioner_unit_number,
       un.unit_name                        AS requisitioner_unit_name,
       s.site_investigator                 AS site_investigator_rolodex_id,
       rlx.last_name                       AS site_investigator_last_name,
       rlx.first_name                      AS site_investigator_first_name,
       s.start_date                        AS start_date,
       s.end_date                          AS end_date,
       s.closeout_date                     AS closeout_date,
       s.date_of_fully_executed            AS date_of_fully_executed,
       s.account_number                    AS account_number,
       s.purchase_order_num                AS purchase_order_number,
       s.requisition_number                AS requisition_number,
       s.archive_location                  AS archive_location,
       s.f_and_a_rate                       AS f_and_a_rate,
       s.de_minimus                        AS de_minimus_flag,
       s.ffata_required                    AS ffata_required,
       s.fsrs_subaward_number              AS fsrs_subaward_number,
       s.award_sponsor_name                AS award_sponsor_name,
       s.award_prime_sponsor_name          AS award_prime_sponsor_name,
       s.fed_award_proj_desc               AS federal_award_project_description,
       DBMS_LOB.SUBSTR(s.comments, 4000, 1) AS comments,
       ex.date_received                    AS bu_date_received,
       s.update_timestamp                  AS update_timestamp,
       s.update_user                       AS update_user
FROM       kcoeus.subaward s
JOIN       huron_subaward_version v   ON v.subaward_id = s.subaward_id
LEFT JOIN  kcoeus.subaward_extension  ex ON ex.subaward_id       = s.subaward_id
LEFT JOIN  kcoeus.subaward_status     st ON st.subaward_status_code = s.status_code
LEFT JOIN  kcoeus.award_type          at ON at.award_type_code    = s.subaward_type_code
LEFT JOIN  kcoeus.subcontract_cost_type ct ON ct.cost_type_code   = TO_CHAR(s.cost_type)
LEFT JOIN  kcoeus.organization        o  ON o.organization_id     = s.organization_id
LEFT JOIN  kcoeus.unit                un ON un.unit_number        = s.requisitioner_unit
LEFT JOIN  kcoeus.rolodex             rlx ON rlx.rolodex_id       = s.site_investigator

-- HURON_SUBAWARD -- Subaward root, one row per SUBAWARD_CODE.
--
-- SUBAWARD_TYPE_CODE decodes against AWARD_TYPE, not a subaward-specific table. We
-- found that in the OJB mapping (subAwardType -> AwardType) rather than by guessing
-- from the name, and all 11 codes in use resolve with 0 unmatched.
--
-- COST_TYPE is NUMBER but SUBCONTRACT_COST_TYPE.COST_TYPE_CODE is VARCHAR2, so the
-- join needs TO_CHAR. 0 unmatched.
--
-- SUBAWARD_EXTENSION is BU's and holds one field, DATE_RECEIVED. It is 1:1 on
-- SUBAWARD_ID (93,060 rows, 93,060 distinct, 0 orphans) and populated on every row
-- with 2,825 distinct values, so we folded it into the root instead of making it a
-- separate dataset.
