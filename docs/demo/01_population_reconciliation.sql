-- DEMO 1 - The whole Grants population in one query.
--
-- Four business objects, physical rows against business records, and how many
-- versions KC is carrying behind each record. This is the single best opener:
-- it shows the scale of the conversion and the versioning problem at the same
-- time.
--
-- Read-only. Four full table counts - expect a few seconds, not instant.

SELECT 'Award'                  AS business_object,
       COUNT(*)                                             AS physical_rows,
       COUNT(DISTINCT a.award_number)                       AS business_records,
       ROUND(COUNT(*) / COUNT(DISTINCT a.award_number), 1)  AS versions_per_record
FROM   kcoeus.award a
UNION ALL
SELECT 'Institutional Proposal',
       COUNT(*),
       COUNT(DISTINCT p.proposal_number),
       ROUND(COUNT(*) / COUNT(DISTINCT p.proposal_number), 1)
FROM   kcoeus.proposal p
UNION ALL
SELECT 'Subaward',
       COUNT(*),
       COUNT(DISTINCT s.subaward_code),
       ROUND(COUNT(*) / COUNT(DISTINCT s.subaward_code), 1)
FROM   kcoeus.subaward s
UNION ALL
SELECT 'Negotiation',
       COUNT(*),
       COUNT(DISTINCT n.negotiation_id),
       ROUND(COUNT(*) / COUNT(DISTINCT n.negotiation_id), 1)
FROM   kcoeus.negotiation n
ORDER  BY physical_rows DESC
