-- Grants on the two views ENHC2008944 touched.
--
-- We did not re-run any of these. CREATE OR REPLACE VIEW keeps existing grants,
-- and we confirmed that after the deploy - all seven were still there. They are
-- written down so the expected state is recorded somewhere, not because anyone
-- needs to run them.
--
-- Read from DBA_TAB_PRIVS on 2026-09-11, after the deploy.

-- SAPBWKCRM.AWARDS_MAXSEQ
--   GRANT SELECT ON SAPBWKCRM.AWARDS_MAXSEQ TO KCOEUS;
--   GRANT SELECT ON SAPBWKCRM.AWARDS_MAXSEQ TO KCRM_SELECT;
--   GRANT SELECT ON SAPBWKCRM.AWARDS_MAXSEQ TO KCRM_UPDATE;
--   GRANT SELECT ON SAPBWKCRM.AWARDS_MAXSEQ TO SAPBWKCRM_READ_ONLY;

-- SAPBWKCRM.AAI_AAT_MAXSEQ
--   GRANT SELECT ON SAPBWKCRM.AAI_AAT_MAXSEQ TO KCRM_SELECT;
--   GRANT SELECT ON SAPBWKCRM.AAI_AAT_MAXSEQ TO KCRM_UPDATE;
--   GRANT SELECT ON SAPBWKCRM.AAI_AAT_MAXSEQ TO SAPBWKCRM_READ_ONLY;
--
-- AAI_AAT_MAXSEQ is not granted to KCOEUS. That is why the KCOEUS read-only
-- runner in this repo cannot query it - see the README.

-- Prove the grants survived a replace. Expect the seven rows above.
SELECT TABLE_NAME,
       GRANTEE,
       PRIVILEGE
FROM   DBA_TAB_PRIVS
WHERE  OWNER = 'SAPBWKCRM'
AND    TABLE_NAME IN ('AWARDS_MAXSEQ', 'AAI_AAT_MAXSEQ')
ORDER  BY TABLE_NAME, GRANTEE;
