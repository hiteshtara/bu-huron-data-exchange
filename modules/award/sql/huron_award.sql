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
       /* ---- lineage keys ---------------------------------------------- */
       a.award_id                          AS award_id,
       a.award_number                      AS award_number,
       a.sequence_number                   AS sequence_number,
       a.document_number                   AS document_number,
       a.proposal_number                   AS source_proposal_number,
       a.account_number                    AS account_number,
       /* ---- version / sequence state ---------------------------------- */
       a.award_sequence_status             AS award_sequence_status,
       a.ver_nbr                           AS version_number,
       /* ---- core business fields (code + description) ------------------ */
       a.title                             AS award_title,
       a.status_code                       AS status_code,
       ast.description                     AS status_description,
       a.award_type_code                   AS award_type_code,
       atyp.description                    AS award_type_description,
       a.activity_type_code                AS activity_type_code,
       act.description                     AS activity_type_description,
       a.transaction_type_code             AS transaction_type_code,
       att.description                     AS transaction_type_description,
       a.account_type_code                 AS account_type_code,
       acct.description                    AS account_type_description,
       a.basis_of_payment_code             AS basis_of_payment_code,
       bop.description                     AS basis_of_payment_description,
       a.method_of_payment_code            AS method_of_payment_code,
       mop.description                     AS method_of_payment_description,
       /* ---- sponsor / unit (code + name) ------------------------------- */
       a.sponsor_code                      AS sponsor_code,
       spn.sponsor_name                    AS sponsor_name,
       a.prime_sponsor_code                AS prime_sponsor_code,
       psp.sponsor_name                    AS prime_sponsor_name,
       a.lead_unit_number                  AS lead_unit_number,
       un.unit_name                        AS lead_unit_name,
       /* ---- sponsor identifiers ---------------------------------------- */
       a.sponsor_award_number              AS sponsor_award_number,
       a.modification_number               AS modification_number,
       a.fain_id                           AS fain_id,
       a.fed_award_year                    AS federal_award_year,
       a.fed_award_date                    AS federal_award_date,
       a.nsf_sequence_number               AS nsf_sequence_number,
       nsf.nsf_code                        AS nsf_science_code,
       nsf.description                     AS nsf_science_code_description,
       /* ---- dates ------------------------------------------------------ */
       a.award_effective_date              AS award_effective_date,
       a.award_execution_date              AS award_execution_date,
       a.begin_date                        AS begin_date,
       a.closeout_date                     AS closeout_date,
       a.notice_date                       AS notice_date,
       a.fin_account_creation_date         AS fin_account_creation_date,
       /* ---- pre-award amounts ------------------------------------------ */
       a.pre_award_authorized_amount       AS pre_award_authorized_amount,
       a.pre_award_effective_date          AS pre_award_effective_date,
       a.pre_award_in_authorized_amount    AS pre_award_inst_authorized_amount,
       a.pre_award_inst_effective_date     AS pre_award_inst_effective_date,
       /* ---- indicators -------------------------------------------------- */
       a.cost_sharing_indicator            AS cost_sharing_indicator,
       a.idc_indicator                     AS idc_indicator,
       a.special_review_indicator          AS special_review_indicator,
       a.apprvd_equipment_indicator        AS approved_equipment_indicator,
       a.apprvd_foreign_trip_indicator     AS approved_foreign_trip_indicator,
       a.apprvd_subcontract_indicator      AS approved_subcontract_indicator,
       a.payment_schedule_indicator        AS payment_schedule_indicator,
       a.science_code_indicator            AS science_code_indicator,
       a.transfer_sponsor_indicator        AS transfer_sponsor_indicator,
       a.sub_plan_flag                     AS sub_plan_flag,
       a.hierarchy_sync_child              AS hierarchy_sync_child,
       /* ---- rates / financial ------------------------------------------ */
       a.special_eb_rate_on_campus         AS special_eb_rate_on_campus,
       a.special_eb_rate_off_campus        AS special_eb_rate_off_campus,
       a.fin_chart_of_accounts_code        AS fin_chart_of_accounts_code,
       a.fin_account_doc_nbr               AS fin_account_doc_nbr,
       a.dfafs_number                      AS dfafs_number,
       a.procurement_priority_code         AS procurement_priority_code,
       a.archive_location                  AS archive_location,
       a.template_code                     AS template_code,
       /* ---- BU extension fields (AWARD_EXTENSION, 1:1 on award_id) ----- */
       ax.grant_number                     AS bu_grant_number,
       ax.prime_sponsor_award_id           AS bu_prime_sponsor_award_id,
       ax.federal_clinical_trial           AS bu_federal_clinical_trial,
       ax.major_project                    AS bu_major_project,
       ax.conference_grant                 AS bu_conference_grant,
       ax.program_income                   AS bu_program_income,
       ax.a133_cluster                     AS bu_a133_cluster,
       ax.arra_code                        AS bu_arra_code,
       ax.avc_indicator                    AS bu_avc_indicator,
       ax.child_type                       AS bu_child_type,
       ax.child_description                AS bu_child_description,
       ax.proposed_indicator               AS bu_proposed_indicator,
       ax.last_trans_date                  AS bu_last_transaction_date,
       ax.fringe_not_allowed_indicator     AS bu_fringe_not_allowed_indicator,
       ax.interest_earned                  AS bu_interest_earned,
       ax.interest_earned_account_number   AS bu_interest_earned_account_number,
       ax.federal_rate_date                AS bu_federal_rate_date,
       ax.bu_bmc_fa_split                  AS bu_bmc_fa_split,
       ax.stock_award                      AS bu_stock_award,
       ax.foreign_currency_award           AS bu_foreign_currency_award,
       ax.nce_notification_date            AS bu_nce_notification_date,
       ax.clinical_trial_initiated_by      AS bu_clinical_trial_initiated_by,
       ax.ind_ide_responsibility           AS bu_ind_ide_responsibility,
       ax.clinical_trial_reg_date          AS bu_clinical_trial_reg_date,
       ax.spuds_record_number              AS bu_spuds_record_number,
       ax.walker_source_number             AS bu_walker_source_number,
       /* ---- audit ------------------------------------------------------- */
       a.update_timestamp                  AS update_timestamp,
       a.update_user                       AS update_user
FROM       kcoeus.award a
LEFT JOIN  kcoeus.award_extension          ax   ON ax.award_id                   = a.award_id
LEFT JOIN  kcoeus.award_status             ast  ON ast.status_code               = TO_CHAR(a.status_code)
LEFT JOIN  kcoeus.award_type               atyp ON atyp.award_type_code          = a.award_type_code
LEFT JOIN  kcoeus.activity_type            act  ON act.activity_type_code        = TO_CHAR(a.activity_type_code)
LEFT JOIN  kcoeus.award_transaction_type   att  ON att.award_transaction_type_code = TO_NUMBER(a.transaction_type_code)
LEFT JOIN  kcoeus.account_type             acct ON acct.account_type_code        = a.account_type_code
LEFT JOIN  kcoeus.award_basis_of_payment   bop  ON bop.basis_of_payment_code     = a.basis_of_payment_code
LEFT JOIN  kcoeus.award_method_of_payment  mop  ON mop.method_of_payment_code    = a.method_of_payment_code
LEFT JOIN  kcoeus.sponsor                  spn  ON spn.sponsor_code              = a.sponsor_code
LEFT JOIN  kcoeus.sponsor                  psp  ON psp.sponsor_code              = a.prime_sponsor_code
LEFT JOIN  kcoeus.unit                     un   ON un.unit_number                = a.lead_unit_number
LEFT JOIN  kcoeus.nsf_codes                nsf  ON nsf.nsf_sequence_number       = a.nsf_sequence_number
JOIN       huron_award_version v ON v.award_id = a.award_id

-- ===========================================================================
-- HURON_GRANTS_AWARD
--
-- Grain      : one row per AWARD sequence (award_id). AWARD is versioned, so an
--              award_number has many sequence_numbers. NOT filtered to the
--              latest sequence -- population selection is a later decision.
-- Source     : KCOEUS.AWARD (57 cols) + KCOEUS.AWARD_EXTENSION (31 cols, BU)
-- Cardinality: AWARD_EXTENSION verified 1:1 on award_id
--              (282,468 rows / 282,468 distinct ids). All lookups are many:1
--              and LEFT JOINed, so no row multiplication.
--
-- Datatype-aware lookup joins (verified against production metadata):
--   status_code          NUMBER(3)  -> AWARD_STATUS.STATUS_CODE  VARCHAR2(3)  -> TO_CHAR
--   activity_type_code   NUMBER(3)  -> ACTIVITY_TYPE...          VARCHAR2(3)  -> TO_CHAR
--   transaction_type_code VARCHAR2(3) -> AWARD_TRANSACTION_TYPE  NUMBER(3)    -> TO_NUMBER
--       safe: 0 non-numeric values in AWARD.TRANSACTION_TYPE_CODE
--   award_type_code, account_type_code, basis/method of payment, sponsor,
--   unit, nsf_sequence_number all join on matching datatypes.
--
-- Unmatched codes (historical, reported not resolved):
--   transaction_type_code 15 rows | sponsor_code 3 rows | prime_sponsor_code 6 rows
--
-- Excluded on purpose: OBJ_ID (framework GUID, no business meaning).
-- Child structures are deliberately NOT joined here -- see the separate
-- HURON_GRANTS_AWARD_* datasets for amounts, persons, terms and custom data.
-- ===========================================================================

-- Award root population rule: one row per AWARD_NUMBER, the version KC marks
-- ACTIVE, falling back to the highest sequence where no ACTIVE row exists
-- (202 award numbers). Verified: 43,202 selected rows for 43,202 award numbers.
-- Children are retrieved through the SELECTED root's AWARD_ID -- MAX(SEQUENCE_NUMBER)
-- is never recomputed on a child table, which would risk mixing versions.
-- Remove the huron_award_version join to expose all historical sequences.
