CREATE TABLE IF NOT EXISTS biogram_profile_banners (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  mime_type TEXT NOT NULL CHECK (mime_type = 'image/jpeg'),
  data_base64 TEXT NOT NULL,
  size_bytes INTEGER NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 327680),
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_biogram_profile_banners_updated
  ON biogram_profile_banners(updated_at);
