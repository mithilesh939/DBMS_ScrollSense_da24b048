-- T1 · Like retraction must be atomic: the like row is ended AND a negative
-- signal row is written. If one write lands and the other does not, neither
-- should take effect.

BEGIN;
    UPDATE Like_ SET retracted_at = '2026-09-01T00:00:00Z' WHERE like_id = 1;
    INSERT INTO Retraction (like_id, retracted_at) VALUES (1, '2026-09-01T00:00:00Z');
    -- deliberate failure: this violates the NOT NULL / type rules on purpose
    SELECT 1/0;
COMMIT;

-- Proof of consistency (run after the failed transaction above):
-- SELECT like_id, retracted_at FROM Like_ WHERE like_id = 1;
-- expect: retracted_at is unchanged from before this script ran
-- SELECT * FROM Retraction WHERE like_id = 1;
-- expect: no extra retraction row beyond what existed before


-- T2 · Moderation decision visibility across connections.
-- Run this half on connection A, leave it open, then query from connection B.
BEGIN;
    INSERT INTO VideoModerationEvent (video_id, state, decided_by_type, decided_by_id, decided_at)
    VALUES (1, 'taken_down', 'reviewer', NULL, '2026-09-01T00:00:00Z');
    -- do not commit yet, leave this open to test visibility from another connection


-- T3 · Handle change limit, twice a year.
BEGIN;
    UPDATE Handle SET ended_at = '2026-09-01T00:00:00Z' WHERE user_id = 20 AND ended_at IS NULL;
    INSERT INTO Handle (user_id, handle, started_at, ended_at) VALUES (20, 'newhandle1', '2026-09-01T00:00:00Z', NULL);
COMMIT;

BEGIN;
    UPDATE Handle SET ended_at = '2026-09-02T00:00:00Z' WHERE user_id = 20 AND ended_at IS NULL;
    INSERT INTO Handle (user_id, handle, started_at, ended_at) VALUES (20, 'newhandle2', '2026-09-02T00:00:00Z', NULL);
COMMIT;

BEGIN;
    UPDATE Handle SET ended_at = '2026-09-03T00:00:00Z' WHERE user_id = 20 AND ended_at IS NULL;
    INSERT INTO Handle (user_id, handle, started_at, ended_at) VALUES (20, 'newhandle3', '2026-09-03T00:00:00Z', NULL);
COMMIT;
