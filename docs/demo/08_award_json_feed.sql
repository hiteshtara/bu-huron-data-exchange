-- DEMO 8 - The same thing as a feed, not a one-off.
--
-- Demo 7 shows one Award as a document. This shows that it is not a party trick:
-- one row per award, each row a complete JSON document, ready to be streamed to a
-- file, posted to an endpoint, or loaded into a staging table as-is.
--
-- Run it with a small FETCH FIRST for the demo. Remove the limit and it is the
-- whole population - 43,202 documents for Award. Nothing about the shape changes
-- between one and all of them, which is the reassuring part.
--
-- Deliberately narrower than demo 7. The point here is the FEED, so keeping each
-- document small keeps the screen readable. Demo 7 is the one that shows depth.
--
-- Read-only.

WITH selected_award AS (
    SELECT award_id, award_number, sequence_number
    FROM (
        SELECT a.award_id,
               a.award_number,
               a.sequence_number,
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
SELECT a.award_number,
       JSON_OBJECT(
         'sourceSystem' VALUE 'KUALI_COEUS',
         'sourceObject' VALUE 'AWARD',
         'sourceKeys'   VALUE JSON_OBJECT(
                                'awardNumber'    VALUE a.award_number,
                                'awardId'        VALUE a.award_id,
                                'sequenceNumber' VALUE a.sequence_number
                              ),
         'title'        VALUE a.title,
         'sponsorCode'  VALUE a.sponsor_code,
         'sponsorName'  VALUE spn.sponsor_name,
         'beginDate'    VALUE TO_CHAR(a.begin_date, 'YYYY-MM-DD'),
         'personCount'  VALUE (SELECT COUNT(*) FROM kcoeus.award_persons p
                                WHERE p.award_id = a.award_id),
         'persons'      VALUE (SELECT JSON_ARRAYAGG(
                                        JSON_OBJECT(
                                          'personId' VALUE p.person_id,
                                          'fullName' VALUE p.full_name,
                                          'roleCode' VALUE p.contact_role_code
                                        ) RETURNING CLOB)
                                FROM kcoeus.award_persons p
                               WHERE p.award_id = a.award_id)
         RETURNING CLOB
       ) AS award_document
FROM       selected_award s
JOIN       kcoeus.award   a   ON a.award_id       = s.award_id
LEFT JOIN  kcoeus.sponsor spn ON spn.sponsor_code = a.sponsor_code
ORDER  BY  a.award_number
FETCH FIRST 10 ROWS ONLY          -- remove for the full 43,202
