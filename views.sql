DROP VIEW IF EXISTS v_public_profile;
CREATE VIEW v_public_profile AS
SELECT
    u.user_id,
    h.handle,
    u.display_name,
    (
        SELECT COUNT(*)
        FROM Follow f
        WHERE f.followee_id = u.user_id
          AND f.ended_at IS NULL
    ) AS follower_count
FROM AppUser u
JOIN Handle h
    ON h.user_id = u.user_id
   AND h.ended_at IS NULL
WHERE u.account_state = 'active';

DROP VIEW IF EXISTS v_video_current_state;
CREATE VIEW v_video_current_state AS
SELECT
    video_id,
    state,
    decided_by_type,
    decided_at
FROM (
    SELECT
        video_id,
        state,
        decided_by_type,
        decided_at,
        ROW_NUMBER() OVER (
            PARTITION BY video_id ORDER BY decided_at DESC
        ) AS rn
    FROM VideoModerationEvent
)
WHERE rn = 1;

DROP VIEW IF EXISTS v_creator_tier_current;
CREATE VIEW v_creator_tier_current AS
SELECT
    creator_id,
    tier,
    valid_from
FROM (
    SELECT
        creator_id,
        tier,
        valid_from,
        ROW_NUMBER() OVER (
            PARTITION BY creator_id ORDER BY valid_from DESC
        ) AS rn
    FROM CreatorTierPeriod
)
WHERE rn = 1;

DROP VIEW IF EXISTS v_video_daily_engagement;
CREATE VIEW v_video_daily_engagement AS
WITH impression_days AS (
    SELECT video_id, date(ts) AS day, COUNT(*) AS impressions
    FROM Impression
    GROUP BY video_id, date(ts)
),
view_days AS (
    SELECT i.video_id, date(i.ts) AS day,
           COUNT(*) AS views,
           SUM((julianday(vs.ended_at) - julianday(vs.started_at)) * 86400.0) AS watch_seconds
    FROM ViewSegment vs
    JOIN Impression i ON i.impression_id = vs.impression_id
    GROUP BY i.video_id, date(i.ts)
),
like_days AS (
    SELECT video_id, date(liked_at) AS day, COUNT(*) AS like_count
    FROM Like_
    GROUP BY video_id, date(liked_at)
),
retraction_days AS (
    SELECT l.video_id, date(r.retracted_at) AS day, COUNT(*) AS retraction_count
    FROM Retraction r
    JOIN Like_ l ON l.like_id = r.like_id
    GROUP BY l.video_id, date(r.retracted_at)
)
SELECT
    id.video_id,
    id.day,
    id.impressions,
    COALESCE(vd.views, 0) AS views,
    COALESCE(vd.watch_seconds, 0) AS watch_seconds,
    COALESCE(ld.like_count, 0) - COALESCE(rd.retraction_count, 0) AS net_likes
FROM impression_days id
LEFT JOIN view_days vd ON vd.video_id = id.video_id AND vd.day = id.day
LEFT JOIN like_days ld ON ld.video_id = id.video_id AND ld.day = id.day
LEFT JOIN retraction_days rd ON rd.video_id = id.video_id AND rd.day = id.day;

DROP VIEW IF EXISTS v_turn_cost;
CREATE VIEW v_turn_cost AS
SELECT
    t.turn_id,
    t.session_id,
    t.occurred_at,
    tu.input_tokens,
    tu.output_tokens,
    tu.cached_tokens,
    mp.input_rate,
    mp.output_rate,
    mp.cached_input_rate,
    (tu.input_tokens * mp.input_rate
     + tu.output_tokens * mp.output_rate
     + tu.cached_tokens * mp.cached_input_rate) AS turn_cost
FROM Turn t
JOIN TurnUsage tu ON tu.turn_id = t.turn_id
JOIN ModelPricePeriod mp
    ON mp.model_id = t.model_id AND mp.priced_at = t.priced_at;