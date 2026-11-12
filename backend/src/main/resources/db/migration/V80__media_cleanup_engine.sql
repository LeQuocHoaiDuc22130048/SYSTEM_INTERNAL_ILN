-- V80: Media Cleanup Engine (ShedLock, Media Assets, References, Cleanup Jobs & Audit Logs)

CREATE TABLE IF NOT EXISTS shedlock (
    name       VARCHAR(64)  NOT NULL PRIMARY KEY,
    lock_until TIMESTAMP WITH TIME ZONE NOT NULL,
    locked_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    locked_by  VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS media_assets (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_name         VARCHAR(100) NOT NULL,
    object_key          VARCHAR(500) NOT NULL,
    storage_url         VARCHAR(500),
    original_filename   VARCHAR(255),
    content_type        VARCHAR(120),
    file_size           BIGINT NOT NULL DEFAULT 0,
    checksum_sha256     VARCHAR(64),
    module_source       VARCHAR(50) NOT NULL DEFAULT 'OTHER',
    status              VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    expires_at          TIMESTAMP WITH TIME ZONE,
    deleted_at          TIMESTAMP WITH TIME ZONE,
    retry_count         INT NOT NULL DEFAULT 0,
    max_retries         INT NOT NULL DEFAULT 5,
    next_retry_at       TIMESTAMP WITH TIME ZONE,
    claimed_by_job_id   UUID,
    claimed_at          TIMESTAMP WITH TIME ZONE,
    last_error_code     VARCHAR(100),
    last_error_message  TEXT,
    created_by          UUID,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_media_assets_bucket_key UNIQUE (bucket_name, object_key)
);

CREATE INDEX IF NOT EXISTS idx_media_assets_cleanup_candidates
    ON media_assets (status, expires_at, next_retry_at);

CREATE INDEX IF NOT EXISTS idx_media_assets_storage_url
    ON media_assets (storage_url);

CREATE INDEX IF NOT EXISTS idx_media_assets_claimed
    ON media_assets (status, claimed_at);

CREATE TABLE IF NOT EXISTS media_references (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id        UUID NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
    reference_type  VARCHAR(50) NOT NULL,
    reference_id    VARCHAR(100) NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    released_at     TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uq_media_references_unique UNIQUE (media_id, reference_type, reference_id)
);

CREATE INDEX IF NOT EXISTS idx_media_references_active
    ON media_references (media_id, is_active);

CREATE INDEX IF NOT EXISTS idx_media_references_lookup
    ON media_references (reference_type, reference_id);

CREATE TABLE IF NOT EXISTS media_cleanup_jobs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_code            VARCHAR(60) NOT NULL UNIQUE,
    trigger_type        VARCHAR(30) NOT NULL,
    status              VARCHAR(30) NOT NULL,
    instance_id         VARCHAR(150) NOT NULL,
    batch_size          INT NOT NULL DEFAULT 100,
    total_batches       INT NOT NULL DEFAULT 0,
    total_processed     INT NOT NULL DEFAULT 0,
    deleted_count       INT NOT NULL DEFAULT 0,
    failed_count        INT NOT NULL DEFAULT 0,
    skipped_count       INT NOT NULL DEFAULT 0,
    freed_bytes         BIGINT NOT NULL DEFAULT 0,
    started_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_heartbeat_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    finished_at         TIMESTAMP WITH TIME ZONE,
    error_summary       TEXT
);

CREATE INDEX IF NOT EXISTS idx_media_cleanup_jobs_status
    ON media_cleanup_jobs (status, last_heartbeat_at);

CREATE INDEX IF NOT EXISTS idx_media_cleanup_jobs_started_at
    ON media_cleanup_jobs (started_at DESC);

CREATE TABLE IF NOT EXISTS media_cleanup_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id          UUID NOT NULL REFERENCES media_cleanup_jobs(id) ON DELETE CASCADE,
    media_id        UUID NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
    bucket_name     VARCHAR(100) NOT NULL,
    object_key      VARCHAR(500) NOT NULL,
    file_size       BIGINT NOT NULL DEFAULT 0,
    action          VARCHAR(40) NOT NULL,
    outcome         VARCHAR(20) NOT NULL,
    attempt_number  INT NOT NULL DEFAULT 1,
    duration_ms     BIGINT NOT NULL DEFAULT 0,
    error_code      VARCHAR(100),
    error_message   TEXT,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_media_cleanup_logs_job_id
    ON media_cleanup_logs (job_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_media_cleanup_logs_media_id
    ON media_cleanup_logs (media_id, created_at DESC);

