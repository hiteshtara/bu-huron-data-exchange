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
       /* ---- lineage keys ---------------------------------------------- */
       p.proposal_id                       AS proposal_id,
       p.proposal_number                   AS proposal_number,
       p.sequence_number                   AS sequence_number,
       p.document_number                   AS document_number,
       v.selection_rule                    AS root_selection_rule,
       /* ---- version state ---------------------------------------------- */
       p.proposal_sequence_status          AS proposal_sequence_status,
       p.ver_nbr                           AS version_number,
       /* ---- core business fields (code + description) ------------------ */
       p.title                             AS project_title,
       p.status_code                       AS status_code,
       ps.description                      AS status_description,
       p.proposal_type_code                AS proposal_type_code,
       pt.description                      AS proposal_type_description,
       p.activity_type_code                AS activity_type_code,
       act.description                     AS activity_type_description,
       p.award_type_code                   AS award_type_code,
       at.description                      AS award_type_description,
       p.notice_of_opportunity_code        AS notice_of_opportunity_code,
       noo.description                     AS notice_of_opportunity_description,
       /* ---- sponsor / unit --------------------------------------------- */
       p.sponsor_code                      AS sponsor_code,
       spn.sponsor_name                    AS sponsor_name,
       p.prime_sponsor_code                AS prime_sponsor_code,
       psp.sponsor_name                    AS prime_sponsor_name,
       p.sponsor_proposal_number           AS sponsor_proposal_number,
       p.lead_unit_number                  AS lead_unit_number,
       un.unit_name                        AS lead_unit_name,
       /* ---- external contact ------------------------------------------- */
       p.rolodex_id                        AS rolodex_id,
       p.nsf_sequence_number               AS nsf_sequence_number,
       nsf.nsf_code                        AS nsf_science_code,
       nsf.description                     AS nsf_science_code_description,
       /* ---- dates / periods -------------------------------------------- */
       p.requested_start_date_initial      AS requested_start_date_initial,
       p.requested_end_date_initial        AS requested_end_date_initial,
       p.requested_start_date_total        AS requested_start_date_total,
       p.requested_end_date_total          AS requested_end_date_total,
       p.deadline_date                     AS deadline_date,
       p.deadline_time                     AS deadline_time,
       p.deadline_type                     AS deadline_type,
       p.fiscal_month                      AS fiscal_month,
       p.fiscal_year                       AS fiscal_year,
       p.create_timestamp                  AS create_timestamp,
       /* ---- money ------------------------------------------------------- */
       p.total_direct_cost_initial         AS total_direct_cost_initial,
       p.total_direct_cost_total           AS total_direct_cost_total,
       p.total_indirect_cost_initial       AS total_indirect_cost_initial,
       p.total_indirect_cost_total         AS total_indirect_cost_total,
       /* ---- accounts / linkage ------------------------------------------ */
       p.current_account_number            AS current_account_number,
       p.current_award_number              AS current_award_number,
       p.type_of_account                   AS type_of_account,
       p.opportunity                       AS opportunity,
       p.initial_contract_admin            AS initial_contract_admin,
       /* ---- indicators --------------------------------------------------- */
       p.cost_sharing_indicator            AS cost_sharing_indicator,
       p.idc_rate_indicator                AS idc_rate_indicator,
       p.special_review_indicator          AS special_review_indicator,
       p.subcontract_flag                  AS subcontract_flag,
       p.science_code_indicator            AS science_code_indicator,
       p.ip_review_activity_indicator      AS ip_review_activity_indicator,
       /* ---- graduate students -------------------------------------------- */
       p.grad_stud_headcount               AS grad_student_headcount,
       p.grad_stud_person_months           AS grad_student_person_months,
       /* ---- mailing ------------------------------------------------------ */
       p.number_of_copies                  AS number_of_copies,
       p.mail_by                           AS mail_by,
       p.mail_type                         AS mail_type,
       p.mail_account_number               AS mail_account_number,
       p.mail_description                  AS mail_description,
       /* ---- BU extension (PROPOSAL_EXTENSION, 1:1 optional) -------------- */
       ex.major_project                    AS bu_major_project,
       ex.conference_grant                 AS bu_conference_grant,
       ex.individual_fellowship            AS bu_individual_fellowship,
       ex.approved_fa_waiver_indicator     AS bu_approved_fa_waiver_indicator,
       ex.initial_period_fa_rate_1         AS bu_initial_period_fa_rate_1,
       ex.initial_period_fa_rate_2         AS bu_initial_period_fa_rate_2,
       /* ---- audit --------------------------------------------------------- */
       p.update_timestamp                  AS update_timestamp,
       p.update_user                       AS update_user
FROM       kcoeus.proposal p
JOIN       huron_proposal_version v   ON v.proposal_id = p.proposal_id
LEFT JOIN  kcoeus.proposal_extension  ex  ON ex.proposal_id                = p.proposal_id
LEFT JOIN  kcoeus.proposal_status     ps  ON ps.proposal_status_code       = p.status_code
LEFT JOIN  kcoeus.proposal_type       pt  ON pt.proposal_type_code         = p.proposal_type_code
LEFT JOIN  kcoeus.activity_type       act ON act.activity_type_code        = p.activity_type_code
LEFT JOIN  kcoeus.award_type          at  ON at.award_type_code            = p.award_type_code
LEFT JOIN  kcoeus.notice_of_opportunity noo ON noo.notice_of_opportunity_code = p.notice_of_opportunity_code
LEFT JOIN  kcoeus.sponsor             spn ON spn.sponsor_code              = p.sponsor_code
LEFT JOIN  kcoeus.sponsor             psp ON psp.sponsor_code              = p.prime_sponsor_code
LEFT JOIN  kcoeus.unit                un  ON un.unit_number                = p.lead_unit_number
LEFT JOIN  kcoeus.nsf_codes           nsf ON nsf.nsf_sequence_number       = p.nsf_sequence_number

-- HURON_PROPOSAL -- Institutional Proposal root.
--
-- Grain: one row per PROPOSAL_NUMBER, the version KC marks ACTIVE, falling back to the
-- highest sequence where no ACTIVE row exists (52 proposals). 36,863 rows for 36,863
-- proposal numbers. ROOT_SELECTION_RULE records which branch chose each row.
--
-- MAX(SEQUENCE_NUMBER) alone is NOT used: it is unique here, but for 80 proposals the
-- highest sequence is a CANCELED/PENDING/ARCHIVED row while the ACTIVE record of record
-- sits lower. See huron_proposal_latest_version_validation.sql.
--
-- PROPOSAL_EXTENSION is BU-authored and 1:1 on PROPOSAL_ID but OPTIONAL -- 7,762
-- proposals have no extension row -- so it is LEFT JOINed. All lookups are many:1.
-- Child collections are NOT joined here; see the huron_proposal_* datasets.
