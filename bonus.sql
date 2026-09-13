-- Bonus 1: trigger-based audit log for moderation decisions

CREATE TABLE IF NOT EXISTS ModerationAuditLog (
    audit_id INTEGER PRIMARY KEY,
    event_id INTEGER NOT NULL,
    video_id INTEGER NOT NULL,
    logged_at TEXT NOT NULL
);

DROP TRIGGER IF EXISTS trg_moderation_audit;
CREATE TRIGGER trg_moderation_audit
AFTER INSERT ON VideoModerationEvent
FOR EACH ROW
BEGIN
    INSERT INTO ModerationAuditLog (event_id, video_id, logged_at)
    VALUES (NEW.event_id, NEW.video_id, NEW.decided_at);
END;


-- Bonus 2: trigger preventing overlapping validity intervals on CreatorTierPeriod

DROP TRIGGER IF EXISTS trg_prevent_overlapping_tier_periods;
CREATE TRIGGER trg_prevent_overlapping_tier_periods
BEFORE INSERT ON CreatorTierPeriod
FOR EACH ROW
WHEN EXISTS (
    SELECT 1 FROM CreatorTierPeriod
    WHERE creator_id = NEW.creator_id
      AND valid_from < COALESCE(NEW.valid_to, '9999-12-31')
      AND COALESCE(valid_to, '9999-12-31') > NEW.valid_from
)
BEGIN
    SELECT RAISE(ABORT, 'overlapping tier period for this creator');
END;