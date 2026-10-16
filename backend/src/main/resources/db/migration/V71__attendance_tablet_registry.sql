CREATE TABLE attendance_tablets (
 id uuid PRIMARY KEY, account_id uuid NOT NULL REFERENCES users(id), installation_id varchar(100) NOT NULL UNIQUE,
 secret_hash varchar(100) NOT NULL, name varchar(100) NOT NULL, status varchar(30) NOT NULL CHECK(status IN ('PENDING','APPROVED','BLOCKED')),
 model varchar(100), os_version varchar(100), app_version varchar(100), last_seen_at timestamptz, last_sync_at timestamptz,
 created_at timestamptz NOT NULL, pending_count integer NOT NULL DEFAULT 0 CHECK(pending_count>=0), status_version bigint NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX attendance_tablets_one_approved ON attendance_tablets(account_id) WHERE status='APPROVED';
CREATE TABLE attendance_tablet_leases (
 id uuid PRIMARY KEY, device_id uuid NOT NULL REFERENCES attendance_tablets(id), account_id uuid NOT NULL REFERENCES users(id),
 issued_at timestamptz NOT NULL, expires_at timestamptz NOT NULL, status_version bigint NOT NULL, signature varchar(100) NOT NULL
);
CREATE INDEX attendance_tablet_leases_device ON attendance_tablet_leases(device_id,issued_at);
CREATE TABLE attendance_tablet_events (
 id uuid PRIMARY KEY, device_id uuid NOT NULL REFERENCES attendance_tablets(id), actor_id uuid NOT NULL REFERENCES users(id),
 action varchar(100) NOT NULL, reason varchar(500), occurred_at timestamptz NOT NULL
);
CREATE INDEX attendance_tablet_events_device ON attendance_tablet_events(device_id,occurred_at);
CREATE TABLE attendance_tablet_submissions (
 id uuid PRIMARY KEY, device_id uuid NOT NULL REFERENCES attendance_tablets(id), account_id uuid NOT NULL REFERENCES users(id),
 local_log_id varchar(120) NOT NULL, payload_hash varchar(100) NOT NULL, payload text NOT NULL,
 status varchar(30) NOT NULL, error varchar(500), record_id uuid REFERENCES attendance_records(id), reviewed_by uuid REFERENCES users(id),
 employee_id uuid, captured_at timestamptz, attendance_type varchar(5),
 reason varchar(500), created_at timestamptz NOT NULL, reviewed_at timestamptz,
 UNIQUE(device_id,local_log_id)
);
CREATE INDEX attendance_tablet_submissions_status ON attendance_tablet_submissions(status,created_at);
