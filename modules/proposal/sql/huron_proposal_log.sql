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
       v.proposal_id                       AS proposal_id,
       l.proposal_number                   AS proposal_number,
       v.sequence_number                   AS proposal_sequence_number,
       l.proposal_log_type_code            AS proposal_log_type_code,
       lt.description                      AS proposal_log_type_description,
       l.log_status                        AS log_status,
       ls.description                      AS log_status_description,
       l.proposal_type_code                AS proposal_type_code,
       pt.description                      AS proposal_type_description,
       l.title                             AS title,
       l.pi_id                             AS pi_id,
       l.pi_name                           AS pi_name,
       l.rolodex_id                        AS rolodex_id,
       l.lead_unit                         AS lead_unit_number,
       un.unit_name                        AS lead_unit_name,
       l.sponsor_code                      AS sponsor_code,
       l.sponsor_name                      AS sponsor_name_entered,
       spn.sponsor_name                    AS sponsor_name_lookup,
       l.deadline_date                     AS deadline_date,
       l.deadline_time                     AS deadline_time,
       l.fiscal_month                      AS fiscal_month,
       l.fiscal_year                       AS fiscal_year,
       l.merged_with                       AS merged_with_proposal_number,
       l.inst_proposal_number              AS legacy_inst_proposal_number,
       DBMS_LOB.SUBSTR(l.comments, 2000, 1) AS comments,
       lx.bu_complete_prop_recievd_date    AS bu_complete_proposal_received_date,
       l.create_timestamp                  AS create_timestamp,
       l.create_user                       AS create_user,
       l.ver_nbr                           AS version_number,
       l.update_timestamp                  AS update_timestamp,
       l.update_user                       AS update_user
FROM       kcoeus.proposal_log l
JOIN       huron_proposal_version v ON v.proposal_number = l.proposal_number
LEFT JOIN  kcoeus.proposal_log_extension lx ON lx.proposal_number = l.proposal_number
LEFT JOIN  kcoeus.proposal_log_type      lt ON lt.proposal_log_type_code = l.proposal_log_type_code
LEFT JOIN  kcoeus.proposal_log_status    ls ON ls.proposal_log_status_code = l.log_status
LEFT JOIN  kcoeus.proposal_type          pt ON pt.proposal_type_code = l.proposal_type_code
LEFT JOIN  kcoeus.unit                   un ON un.unit_number = l.lead_unit
LEFT JOIN  kcoeus.sponsor                spn ON spn.sponsor_code = l.sponsor_code

-- The INTAKE record the proposal was created from. PROPOSAL_LOG is a separate business
-- object with its own primary key (PROPOSAL_NUMBER) and no ORM relationship to
-- InstitutionalProposal in either direction -- it shares the business key. 36,860 of
-- 36,863 proposal numbers have a log row; 1,136 logs never became proposals and are
-- therefore absent here.
--
-- This dataset joins on PROPOSAL_NUMBER, NOT PROPOSAL_ID -- the log is not versioned.
--
-- LEGACY_INST_PROPOSAL_NUMBER is exposed but must NOT be used as a join key: it is a
-- 7-character legacy identifier that matches no PROPOSAL_NUMBER (which are 8
-- characters), even after trimming leading zeros. Reported for BU to explain.
