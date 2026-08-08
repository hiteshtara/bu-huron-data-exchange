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
       ti.subaward_id                      AS subaward_id,
       ti.subaward_code                    AS subaward_code,
       ti.sequence_number                  AS sequence_number,
       ti.sow_or_sub_proposal_budget         AS sow_or_sub_proposal_budget,
       ti.sub_proposal_date                  AS sub_proposal_date,
       ti.invoice_or_payment_contact         AS invoice_or_payment_contact,
       ti.final_stmt_of_costs_contact        AS final_stmt_of_costs_contact,
       ti.change_requests_contact            AS change_requests_contact,
       ti.termination_contact                AS termination_contact,
       ti.no_cost_extension_contact          AS no_cost_extension_contact,
       ti.perf_site_diff_from_org_addr       AS perf_site_diff_from_org_addr,
       ti.perf_site_same_as_sub_pi_addr      AS perf_site_same_as_sub_pi_addr,
       ti.sub_registered_in_ccr              AS sub_registered_in_ccr,
       ti.sub_exempt_from_reporting_comp     AS sub_exempt_from_reporting_comp,
       ti.parent_duns_number                 AS parent_duns_number,
       ti.parent_congressional_district      AS parent_congressional_district,
       ti.exempt_from_rprtg_exec_comp        AS exempt_from_rprtg_exec_comp,
       ti.copyright_type                     AS copyright_type,
       ti.automatic_carry_forward            AS automatic_carry_forward,
       ti.carry_forward_requests_sent_to     AS carry_forward_requests_sent_to,
       ti.treatment_prgm_income_additive     AS treatment_prgm_income_additive,
       ti.applicable_program_regulations     AS applicable_program_regulations,
       ti.applicable_program_regs_date       AS applicable_program_regs_date,
       ti.r_and_d                            AS r_and_d,
       ti.includes_cost_sharing              AS includes_cost_sharing,
       ti.fcio                               AS fcio,
       ti.invoices_emailed                   AS invoices_emailed,
       ti.invoice_address_diff               AS invoice_address_diff,
       ti.invoice_email_diff                 AS invoice_email_diff,
       ti.fcio_subrec_policy_cd              AS fcio_subrec_policy_cd,
       ti.animal_flag                        AS animal_flag,
       ti.animal_pte_send_cd                 AS animal_pte_send_cd,
       ti.animal_pte_nr_cd                   AS animal_pte_nr_cd,
       ti.human_flag                         AS human_flag,
       ti.human_pte_send_cd                  AS human_pte_send_cd,
       ti.human_pte_nr_cd                    AS human_pte_nr_cd,
       ti.human_data_exchange_agree_cd       AS human_data_exchange_agree_cd,
       ti.human_data_exchange_terms_cd       AS human_data_exchange_terms_cd,
       ti.mpi_award                          AS mpi_award,
       ti.mpi_leadership_plan                AS mpi_leadership_plan,
       ti.additional_terms                   AS additional_terms,
       ti.treatment_of_income                AS treatment_of_income,
       ti.data_sharing_attachment            AS data_sharing_attachment,
       ti.final_statement_due_cd             AS final_statement_due_cd,
       ti.data_sharing_cd                    AS data_sharing_cd,
       ti.irb_iacuc_contact                  AS irb_iacuc_contact,
       ti.sub_change_requests_contact        AS sub_change_requests_contact,
       ti.sub_termination_contact            AS sub_termination_contact,
       ti.human_subjects                     AS human_subjects,
       ti.human_exempt_docs                  AS human_exempt_docs,
       ti.human_includes_clinical_trials     AS human_includes_clinical_trials,
       ti.update_timestamp                 AS update_timestamp,
       ti.update_user                      AS update_user
FROM       kcoeus.subaward_template_info ti
JOIN       huron_subaward_version v ON v.subaward_id = ti.subaward_id

-- The agreement terms captured on each subaward: copyright type, carry-forward and
-- program-income treatment, invoicing contacts, animal and human-subject flags, data
-- sharing, MPI leadership, and the FFATA/CCR registration answers. 48 business columns.
--
-- KC declares this as a collection on SubAward, but in production it is 1:1 -- 93,061
-- rows, 93,061 distinct SUBAWARD_ID, never more than one row per subaward. We kept it
-- as its own dataset rather than folding 48 columns into the root, but it can safely be
-- joined 1:1 if that is more convenient for mapping.
