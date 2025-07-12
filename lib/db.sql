-- Extension pour les UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table des utilisateurs (étendue)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar TEXT,
  bio TEXT,
  followers INTEGER DEFAULT 0,
  following INTEGER DEFAULT 0,
  total_likes INTEGER DEFAULT 0,
  total_gifts INTEGER DEFAULT 0,
  tokens_balance INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT FALSE,
  is_moderator BOOLEAN DEFAULT FALSE,
  preferences JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  last_seen TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des lives (étendue)
CREATE TABLE IF NOT EXISTS lives (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  host_id UUID REFERENCES users(id) ON DELETE CASCADE,
  category TEXT,
  tags TEXT[],
  thumbnail TEXT,
  viewer_count INTEGER DEFAULT 0,
  like_count INTEGER DEFAULT 0,
  gift_count INTEGER DEFAULT 0,
  is_live BOOLEAN DEFAULT FALSE,
  is_private BOOLEAN DEFAULT FALSE,
  max_viewers INTEGER DEFAULT 1000,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  ended_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des messages (étendue)
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'text',
  is_moderated BOOLEAN DEFAULT FALSE,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des réactions
CREATE TABLE IF NOT EXISTS reactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  type TEXT NOT NULL,
  position_x REAL,
  position_y REAL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des gifts
CREATE TABLE IF NOT EXISTS gifts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL,
  sender_avatar TEXT,
  receiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
  gift_type TEXT NOT NULL,
  quantity INTEGER DEFAULT 1,
  total_cost INTEGER NOT NULL,
  animation JSONB,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des transactions de tokens
CREATE TABLE IF NOT EXISTS token_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL, -- 'purchase', 'gift_sent', 'gift_received', 'refund'
  payment_method TEXT,
  reference_id UUID, -- ID du gift ou de la transaction externe
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des followers
CREATE TABLE IF NOT EXISTS follows (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
  followed_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(follower_id, followed_id)
);

-- Table des signalements
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
  moderator_id UUID REFERENCES users(id),
  resolution TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des blocages dans les lives
CREATE TABLE IF NOT EXISTS live_blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  blocked_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  blocked_by UUID REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(live_id, blocked_user_id)
);

-- Table des viewers (pour tracking en temps réel)
CREATE TABLE IF NOT EXISTS live_viewers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  left_at TIMESTAMP WITH TIME ZONE,
  duration INTEGER, -- en secondes
  UNIQUE(live_id, user_id)
);

-- Fonctions pour les compteurs
CREATE OR REPLACE FUNCTION increment_viewer_count(live_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE lives 
  SET viewer_count = viewer_count + 1, updated_at = now()
  WHERE id = live_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION decrement_viewer_count(live_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE lives 
  SET viewer_count = GREATEST(viewer_count - 1, 0), updated_at = now()
  WHERE id = live_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION increment_like_count(live_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE lives 
  SET like_count = like_count + 1, updated_at = now()
  WHERE id = live_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION increment_gift_count(live_id UUID, gift_count INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE lives 
  SET gift_count = gift_count + gift_count, updated_at = now()
  WHERE id = live_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION credit_tokens(user_id UUID, amount INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE users 
  SET tokens_balance = tokens_balance + amount, updated_at = now()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION debit_tokens(user_id UUID, amount INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE users 
  SET tokens_balance = GREATEST(tokens_balance - amount, 0), updated_at = now()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lives_updated_at BEFORE UPDATE ON lives
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON reports
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_lives_is_live ON lives(is_live);
CREATE INDEX IF NOT EXISTS idx_lives_host_id ON lives(host_id);
CREATE INDEX IF NOT EXISTS idx_lives_category ON lives(category);
CREATE INDEX IF NOT EXISTS idx_lives_viewer_count ON lives(viewer_count);
CREATE INDEX IF NOT EXISTS idx_messages_live_id ON messages(live_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_reactions_live_id ON reactions(live_id);
CREATE INDEX IF NOT EXISTS idx_reactions_created_at ON reactions(created_at);
CREATE INDEX IF NOT EXISTS idx_gifts_live_id ON gifts(live_id);
CREATE INDEX IF NOT EXISTS idx_gifts_sender_id ON gifts(sender_id);
CREATE INDEX IF NOT EXISTS idx_gifts_receiver_id ON gifts(receiver_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followed_id ON follows(followed_id);

-- Policies RLS (Row Level Security) - À adapter selon vos besoins
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lives ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE gifts ENABLE ROW LEVEL SECURITY;