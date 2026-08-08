SELECT JSON_OBJECT(
         'proposalId'        VALUE p.proposal_id,
         'proposalNumber'    VALUE p.proposal_number,
         'sequenceNumber'    VALUE p.sequence_number,
         'sequenceStatus'    VALUE p.proposal_sequence_status,
         'projectTitle'      VALUE p.title,
         'statusCode'        VALUE p.status_code,
         'statusDescription' VALUE ps.description,
         'sponsorCode'       VALUE p.sponsor_code,
         'sponsorName'       VALUE spn.sponsor_name,
         'leadUnitNumber'    VALUE p.lead_unit_number,
         'leadUnitName'      VALUE un.unit_name,
         'buExtension'       VALUE JSON_OBJECT(
                                     'majorProject'         VALUE ex.major_project,
                                     'conferenceGrant'      VALUE ex.conference_grant,
                                     'individualFellowship' VALUE ex.individual_fellowship,
                                     'approvedFaWaiver'     VALUE ex.approved_fa_waiver_indicator
                                   ),
         'intakeLog'         VALUE (SELECT JSON_OBJECT(
                                            'logStatus'    VALUE l.log_status,
                                            'deadlineDate' VALUE TO_CHAR(l.deadline_date,'YYYY-MM-DD'),
                                            'piName'       VALUE l.pi_name
                                          )
                                     FROM proposal_log l
                                    WHERE l.proposal_number = p.proposal_number),
         'persons'           VALUE (SELECT JSON_ARRAYAGG(
                                            JSON_OBJECT(
                                              'proposalPersonId' VALUE pp.proposal_person_id,
                                              'personId'         VALUE pp.person_id,
                                              'fullName'         VALUE pp.full_name,
                                              'roleCode'         VALUE pp.contact_role_code,
                                              'totalEffort'      VALUE pp.total_effort
                                            ) RETURNING CLOB)
                                     FROM proposal_persons pp
                                    WHERE pp.proposal_id = p.proposal_id),
         'costShare'         VALUE (SELECT JSON_ARRAYAGG(
                                            JSON_OBJECT(
                                              'projectPeriod' VALUE cs.project_period,
                                              'amount'        VALUE cs.amount,
                                              'sourceAccount' VALUE cs.source_account
                                            ) RETURNING CLOB)
                                     FROM proposal_cost_sharing cs
                                    WHERE cs.proposal_id = p.proposal_id),
         'specialReviews'    VALUE (SELECT JSON_ARRAYAGG(
                                            JSON_OBJECT(
                                              'specialReviewNumber' VALUE sr.special_review_number,
                                              'specialReviewCode'   VALUE sr.special_review_code,
                                              'protocolNumber'      VALUE sr.protocol_number,
                                              'approvalDate'        VALUE TO_CHAR(sr.approval_date,'YYYY-MM-DD')
                                            ) RETURNING CLOB)
                                     FROM proposal_special_review sr
                                    WHERE sr.proposal_id = p.proposal_id),
         'ipReview'          VALUE (SELECT JSON_OBJECT(
                                            'ipReviewId'     VALUE ipr.ip_review_id,
                                            'sequenceStatus' VALUE ipr.ip_review_sequence_status,
                                            'reviewer'       VALUE ipr.ip_reviewer
                                          )
                                     FROM proposal_ip_review_join j
                                     JOIN ip_review ipr ON ipr.ip_review_id = j.ip_review_id
                                    WHERE j.proposal_id = p.proposal_id),
         'customFields'      VALUE (SELECT JSON_ARRAYAGG(
                                            JSON_OBJECT(
                                              'customAttributeId' VALUE cd.custom_attribute_id,
                                              'name'              VALUE ca.name,
                                              'label'             VALUE ca.label,
                                              'groupName'         VALUE ca.group_name,
                                              'value'             VALUE cd.value
                                            ) RETURNING CLOB)
                                     FROM proposal_custom_data cd
                                     LEFT JOIN custom_attribute ca ON ca.id = cd.custom_attribute_id
                                    WHERE cd.proposal_id = p.proposal_id)
         RETURNING CLOB
       ) AS proposal_graph_json
FROM       kcoeus.proposal p
LEFT JOIN  kcoeus.proposal_extension ex  ON ex.proposal_id = p.proposal_id
LEFT JOIN  kcoeus.proposal_status    ps  ON ps.proposal_status_code = p.status_code
LEFT JOIN  kcoeus.sponsor            spn ON spn.sponsor_code = p.sponsor_code
LEFT JOIN  kcoeus.unit               un  ON un.unit_number = p.lead_unit_number
WHERE      p.proposal_id = 251

-- PROOF OF CONCEPT -- ONE proposal only, deliberately pinned by proposal_id.
-- Not the primary interface. Demonstrates that the whole Institutional Proposal
-- graph can be returned as a single nested document with NO Cartesian
-- multiplication: each collection is a correlated scalar subquery feeding
-- JSON_ARRAYAGG, so persons x custom fields x special reviews never cross-multiply.
--
-- Note the two scalar JSON_OBJECT sub-selects (intakeLog, ipReview): both are 1:1 by
-- production evidence -- one PROPOSAL_LOG per proposal number, and exactly one
-- IP_REVIEW per proposal version -- so neither needs JSON_ARRAYAGG.
--
-- Verified on Oracle Database 19c Standard Edition 2. RETURNING CLOB is required --
-- the default VARCHAR2(4000) return overflows on real proposals.
