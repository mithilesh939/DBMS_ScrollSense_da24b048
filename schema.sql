PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;


CREATE TABLE TypeAffinityTest (
    id INTEGER PRIMARY KEY,
    strict_int INTEGER
);


CREATE TABLE AppUser (
    user_id INTEGER PRIMARY KEY,
    phone TEXT,
    google_sub TEXT,
    display_name TEXT NOT NULL,
    account_state TEXT NOT NULL CHECK (account_state IN ('active','deactivated','pending_deletion')),
    deletion_requested_at TEXT,
    created_at TEXT NOT NULL,
    CHECK (phone IS NOT NULL OR google_sub IS NOT NULL)
);

CREATE TABLE Handle (
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    handle TEXT NOT NULL,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    PRIMARY KEY (user_id, started_at)
);


CREATE UNIQUE INDEX idx_handle_active_unique
    ON Handle(handle COLLATE NOCASE)
    WHERE ended_at IS NULL;

CREATE TABLE InterestCategory (
    category_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE InferredInterest (
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES InterestCategory(category_id) ON DELETE RESTRICT,
    score REAL NOT NULL CHECK (score BETWEEN 0 AND 1),
    refreshed_at TEXT NOT NULL,
    PRIMARY KEY (user_id, category_id)
);

CREATE TABLE InterestSuppression (
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES InterestCategory(category_id) ON DELETE CASCADE,
    suppressed_at TEXT NOT NULL,
    PRIMARY KEY (user_id, category_id)
);


CREATE TABLE Creator (
    user_id INTEGER PRIMARY KEY REFERENCES AppUser(user_id) ON DELETE CASCADE,
    became_creator_at TEXT NOT NULL
);

CREATE TABLE CreatorTierPeriod (
    creator_id INTEGER NOT NULL REFERENCES Creator(user_id) ON DELETE CASCADE,
    valid_from TEXT NOT NULL,
    valid_to TEXT,
    tier TEXT NOT NULL CHECK (tier IN ('standard','rising','partner','elite')),
    PRIMARY KEY (creator_id, valid_from)
);

CREATE TABLE AudioTrack (
    track_id INTEGER PRIMARY KEY,
    origin_video_id INTEGER,  -- FK added after Video exists, see below
    source TEXT NOT NULL CHECK (source IN ('original','licensed'))
);

CREATE TABLE Video (
    video_id INTEGER PRIMARY KEY,
    owner_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    duration_ms INTEGER NOT NULL CHECK (duration_ms BETWEEN 20000 AND 90000),
    caption TEXT,
    audio_track_id INTEGER REFERENCES AudioTrack(track_id) ON DELETE SET NULL,
    uploaded_at TEXT NOT NULL
);


CREATE TABLE Hashtag (
    hashtag_id INTEGER PRIMARY KEY,
    text_normalised TEXT NOT NULL UNIQUE
);

CREATE TABLE VideoHashtag (
    video_id INTEGER NOT NULL REFERENCES Video(video_id) ON DELETE CASCADE,
    hashtag_id INTEGER NOT NULL REFERENCES Hashtag(hashtag_id) ON DELETE CASCADE,
    PRIMARY KEY (video_id, hashtag_id)
);

CREATE TABLE ModerationState (
    state_code TEXT PRIMARY KEY CHECK (state_code IN
        ('pending','live','age_restricted','demoted','taken_down'))
);
INSERT INTO ModerationState VALUES ('pending'),('live'),('age_restricted'),('demoted'),('taken_down');

CREATE TABLE VideoModerationEvent (
    event_id INTEGER PRIMARY KEY,
    video_id INTEGER NOT NULL REFERENCES Video(video_id) ON DELETE CASCADE,
    state TEXT NOT NULL REFERENCES ModerationState(state_code) ON DELETE RESTRICT,
    decided_by_type TEXT NOT NULL CHECK (decided_by_type IN ('classifier','reviewer')),
    decided_by_id INTEGER,
    decided_at TEXT NOT NULL
);


CREATE TABLE Follow (
    follower_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    followee_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    PRIMARY KEY (follower_id, followee_id, started_at),
    CHECK (follower_id != followee_id)
);

CREATE TABLE Block (
    blocker_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    blocked_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    blocked_at TEXT NOT NULL,
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);

CREATE TABLE Mute (
    muter_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    muted_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    muted_at TEXT NOT NULL,
    PRIMARY KEY (muter_id, muted_id),
    CHECK (muter_id != muted_id)
);


CREATE TABLE Impression (
    impression_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    video_id INTEGER NOT NULL REFERENCES Video(video_id) ON DELETE CASCADE,
    ts TEXT NOT NULL,
    feed_position INTEGER NOT NULL CHECK (feed_position >= 0),
    model_version TEXT NOT NULL
);

CREATE TABLE ViewSegment (
    segment_id INTEGER PRIMARY KEY,
    impression_id INTEGER NOT NULL REFERENCES Impression(impression_id) ON DELETE CASCADE,
    started_at TEXT NOT NULL,
    ended_at TEXT NOT NULL,
    CHECK (ended_at >= started_at)
);

CREATE TABLE Like_ (
    like_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    video_id INTEGER NOT NULL REFERENCES Video(video_id) ON DELETE CASCADE,
    liked_at TEXT NOT NULL,
    retracted_at TEXT
);

CREATE TABLE Retraction (
    retraction_id INTEGER PRIMARY KEY,
    like_id INTEGER NOT NULL REFERENCES Like_(like_id) ON DELETE CASCADE,
    retracted_at TEXT NOT NULL
);

CREATE TABLE Share (
    share_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    video_id INTEGER NOT NULL REFERENCES Video(video_id) ON DELETE CASCADE,
    destination TEXT NOT NULL CHECK (destination IN ('whatsapp','instagram','copied_link')),
    shared_at TEXT NOT NULL
);

CREATE TABLE Comment (
    comment_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    video_id INTEGER NOT NULL REFERENCES Video(video_id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    commented_at TEXT NOT NULL
);

CREATE TABLE SignalEvent (
    signal_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    video_id INTEGER NOT NULL REFERENCES Video(video_id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL CHECK (signal_type IN ('not_interested','report','follow_from_feed')),
    occurred_at TEXT NOT NULL
);


CREATE TABLE PromptTemplateVersion (
    template_id INTEGER NOT NULL,
    version_no INTEGER NOT NULL,
    text_body TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (template_id, version_no)
);

CREATE TABLE ModelPricePeriod (
    model_id INTEGER NOT NULL,
    priced_at TEXT NOT NULL,
    valid_to TEXT,
    input_rate REAL NOT NULL,
    output_rate REAL NOT NULL,
    cached_input_rate REAL,
    PRIMARY KEY (model_id, priced_at)
);

CREATE TABLE AgentSession (
    session_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id) ON DELETE CASCADE,
    started_at TEXT NOT NULL
);

CREATE TABLE Turn (
    turn_id INTEGER PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES AgentSession(session_id) ON DELETE CASCADE,
    turn_index INTEGER NOT NULL,
    user_message TEXT NOT NULL,
    assistant_message TEXT NOT NULL,
    template_id INTEGER NOT NULL,
    template_version INTEGER NOT NULL,
    model_id INTEGER NOT NULL,
    priced_at TEXT NOT NULL,
    temperature REAL NOT NULL,
    occurred_at TEXT NOT NULL,
    UNIQUE (session_id, turn_index),
    FOREIGN KEY (template_id, template_version) REFERENCES PromptTemplateVersion(template_id, version_no),
    FOREIGN KEY (model_id, priced_at) REFERENCES ModelPricePeriod(model_id, priced_at)
);
CREATE TABLE TurnUsage (
    turn_id INTEGER PRIMARY KEY REFERENCES Turn(turn_id) ON DELETE CASCADE,
    input_tokens INTEGER NOT NULL CHECK (input_tokens >= 0),
    output_tokens INTEGER NOT NULL CHECK (output_tokens >= 0),
    cached_tokens INTEGER NOT NULL CHECK (cached_tokens >= 0)
);

CREATE TABLE ToolCall (
    call_id INTEGER PRIMARY KEY,
    turn_id INTEGER NOT NULL REFERENCES Turn(turn_id) ON DELETE CASCADE,
    parent_call_id INTEGER REFERENCES ToolCall(call_id) ON DELETE CASCADE,
    tool_name TEXT NOT NULL,
    arguments_json TEXT NOT NULL CHECK (json_valid(arguments_json)),
    result_json TEXT CHECK (result_json IS NULL OR json_valid(result_json)),
    latency_ms INTEGER NOT NULL CHECK (latency_ms >= 0),
    errored INTEGER NOT NULL CHECK (errored IN (0,1)),
    called_at TEXT NOT NULL
);

CREATE TABLE JudgeScore (
    score_id INTEGER PRIMARY KEY,
    turn_id INTEGER NOT NULL REFERENCES Turn(turn_id) ON DELETE CASCADE,
    helpfulness REAL NOT NULL CHECK (helpfulness BETWEEN 0 AND 5),
    groundedness REAL NOT NULL CHECK (groundedness BETWEEN 0 AND 5),
    safety REAL NOT NULL CHECK (safety BETWEEN 0 AND 5),
    scored_at TEXT NOT NULL
);

CREATE TABLE UserRating (
    rating_id INTEGER PRIMARY KEY,
    turn_id INTEGER NOT NULL REFERENCES Turn(turn_id) ON DELETE CASCADE,
    thumbs TEXT NOT NULL CHECK (thumbs IN ('up','down')),
    rated_at TEXT NOT NULL
);

CREATE TABLE Recommendation (
    turn_id INTEGER NOT NULL REFERENCES Turn(turn_id) ON DELETE CASCADE,
    position INTEGER NOT NULL CHECK (position >= 0),
    video_id INTEGER NOT NULL REFERENCES Video(video_id) ON DELETE CASCADE,
    PRIMARY KEY (turn_id, position)
);