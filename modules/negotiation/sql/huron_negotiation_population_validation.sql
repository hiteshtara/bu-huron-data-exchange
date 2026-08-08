SELECT
    (SELECT COUNT(*)                          FROM kcoeus.negotiation) AS total_negotiation_rows,
    (SELECT COUNT(DISTINCT negotiation_id)    FROM kcoeus.negotiation) AS distinct_negotiation_id,
    (SELECT COUNT(DISTINCT document_number)   FROM kcoeus.negotiation) AS distinct_document_number,
    (SELECT COUNT(*) FROM kcoeus.version_history
      WHERE seq_owner_class_name LIKE '%negotiations.bo.Negotiation')  AS version_history_rows,
    (SELECT COUNT(*) FROM kcoeus.negotiation n
      JOIN kcoeus.negotiation_association_type t
        ON t.negotiation_assc_type_id = n.negotiation_assc_type_id
     WHERE t.description = 'Award')                                    AS associated_to_award,
    (SELECT COUNT(*) FROM kcoeus.negotiation n
      JOIN kcoeus.negotiation_association_type t
        ON t.negotiation_assc_type_id = n.negotiation_assc_type_id
     WHERE t.description = 'Subaward')                                 AS associated_to_subaward,
    (SELECT COUNT(*) FROM kcoeus.negotiation n
      JOIN kcoeus.negotiation_association_type t
        ON t.negotiation_assc_type_id = n.negotiation_assc_type_id
     WHERE t.description = 'Institutional Proposal')                   AS associated_to_proposal,
    (SELECT COUNT(*) FROM kcoeus.negotiation n
      JOIN kcoeus.negotiation_association_type t
        ON t.negotiation_assc_type_id = n.negotiation_assc_type_id
     WHERE t.description = 'None')                                     AS not_associated,
    (SELECT COUNT(*) FROM kcoeus.negotiation_unassoc_detail)            AS unassociated_detail_rows,
    (SELECT COUNT(DISTINCT negotiation_id)
       FROM kcoeus.negotiation_unassoc_detail)                          AS unassociated_detail_negotiations
FROM dual

-- Negotiation is NOT versioned, and that is the finding.
--
-- Award, Institutional Proposal and Subaward each needed their own rule for picking the
-- current row out of many sequences. Negotiation needs none: NEGOTIATION has no
-- SEQUENCE_NUMBER column and no sequence-status column, one row is one negotiation
-- (11,842 rows, 11,842 distinct NEGOTIATION_ID, 11,842 distinct DOCUMENT_NUMBER), and
-- VERSION_HISTORY holds zero rows for the Negotiation class while it holds plenty for
-- the other three.
--
-- So there is no huron_negotiation_latest_version_validation.sql here. We kept this
-- query anyway because "we checked and it is not versioned" is worth being able to
-- re-run, and because the association counts underneath it are the other half of what
-- makes a Negotiation make sense.
