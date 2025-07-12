-- Script SQL complet pour la base de données Streamy (Supabase/PostgreSQL)
-- Date de création: 2025-07-12

-- Extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ===============================
-- TABLES PRINCIPALES
-- ===============================

-- Table des utilisateurs (complète)
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
  tokens_balance INTEGER DEFAULT 100,
  is_verified BOOLEAN DEFAULT FALSE,
  is_moderator BOOLEAN DEFAULT FALSE,
  preferences JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  last_seen TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des lives (complète)
CREATE TABLE IF NOT EXISTS lives (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  host_id UUID REFERENCES users(id) ON DELETE CASCADE,
  category TEXT DEFAULT 'Général',
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

-- Table des messages (renommée pour correspondre au code)
CREATE TABLE IF NOT EXISTS live_messages (
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

-- Table pour compatibilité (alias)
DROP VIEW IF EXISTS messages;
CREATE VIEW messages AS SELECT * FROM live_messages;

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

-- ===============================
-- TABLES SECONDAIRES
-- ===============================

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

-- Table des signalements de messages
CREATE TABLE IF NOT EXISTS message_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id UUID REFERENCES live_messages(id) ON DELETE CASCADE,
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
  moderator_id UUID REFERENCES users(id),
  resolution TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table des signalements de lives
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT,
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

-- Table des emojis personnalisés pour les lives
CREATE TABLE IF NOT EXISTS live_emojis (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  emoji_code TEXT NOT NULL,
  emoji_url TEXT,
  created_by UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- ===============================
-- FONCTIONS STORED PROCEDURES
-- ===============================

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

-- ===============================
-- TRIGGERS
-- ===============================

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

CREATE TRIGGER update_message_reports_updated_at BEFORE UPDATE ON message_reports
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON reports
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===============================
-- INDEX POUR PERFORMANCES
-- ===============================

-- Index pour les lives
CREATE INDEX IF NOT EXISTS idx_lives_is_live ON lives(is_live);
CREATE INDEX IF NOT EXISTS idx_lives_host_id ON lives(host_id);
CREATE INDEX IF NOT EXISTS idx_lives_category ON lives(category);
CREATE INDEX IF NOT EXISTS idx_lives_viewer_count ON lives(viewer_count DESC);
CREATE INDEX IF NOT EXISTS idx_lives_started_at ON lives(started_at DESC);

-- Index pour les messages
CREATE INDEX IF NOT EXISTS idx_live_messages_live_id ON live_messages(live_id);
CREATE INDEX IF NOT EXISTS idx_live_messages_user_id ON live_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_live_messages_created_at ON live_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_messages_live_created ON live_messages(live_id, created_at DESC);

-- Index pour les réactions
CREATE INDEX IF NOT EXISTS idx_reactions_live_id ON reactions(live_id);
CREATE INDEX IF NOT EXISTS idx_reactions_created_at ON reactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reactions_live_created ON reactions(live_id, created_at DESC);

-- Index pour les gifts
CREATE INDEX IF NOT EXISTS idx_gifts_live_id ON gifts(live_id);
CREATE INDEX IF NOT EXISTS idx_gifts_sender_id ON gifts(sender_id);
CREATE INDEX IF NOT EXISTS idx_gifts_receiver_id ON gifts(receiver_id);
CREATE INDEX IF NOT EXISTS idx_gifts_sent_at ON gifts(sent_at DESC);

-- Index pour les followers
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followed_id ON follows(followed_id);

-- Index pour les viewers
CREATE INDEX IF NOT EXISTS idx_live_viewers_live_id ON live_viewers(live_id);
CREATE INDEX IF NOT EXISTS idx_live_viewers_user_id ON live_viewers(user_id);
CREATE INDEX IF NOT EXISTS idx_live_viewers_joined_at ON live_viewers(joined_at DESC);

-- Index pour les utilisateurs
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_tokens_balance ON users(tokens_balance DESC);

-- Index de recherche textuelle
CREATE INDEX IF NOT EXISTS idx_lives_title_search ON lives USING gin(title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_lives_description_search ON lives USING gin(description gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_username_search ON users USING gin(username gin_trgm_ops);

-- ===============================
-- POLITIQUES RLS (Row Level Security)
-- ===============================

-- Activer RLS sur toutes les tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lives ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE gifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_viewers ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_emojis ENABLE ROW LEVEL SECURITY;

-- Politiques de base (à adapter selon vos besoins de sécurité)

-- Users: chacun peut voir et modifier son propre profil
CREATE POLICY "Users can view all profiles" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = id);

-- Lives: publics en lecture, seul le host peut modifier
CREATE POLICY "Lives are viewable by everyone" ON lives FOR SELECT USING (true);
CREATE POLICY "Users can insert own lives" ON lives FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "Users can update own lives" ON lives FOR UPDATE USING (auth.uid() = host_id);
CREATE POLICY "Users can delete own lives" ON lives FOR DELETE USING (auth.uid() = host_id);

-- Messages: visibles par tous dans un live, seul l'auteur peut modifier
CREATE POLICY "Messages are viewable by everyone" ON live_messages FOR SELECT USING (true);
CREATE POLICY "Users can insert messages" ON live_messages FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own messages" ON live_messages FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own messages" ON live_messages FOR DELETE USING (auth.uid() = user_id);

-- Reactions: visibles par tous, seul l'auteur peut gérer
CREATE POLICY "Reactions are viewable by everyone" ON reactions FOR SELECT USING (true);
CREATE POLICY "Users can insert reactions" ON reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own reactions" ON reactions FOR DELETE USING (auth.uid() = user_id);

-- Gifts: visibles par tous, seul l'expéditeur peut gérer
CREATE POLICY "Gifts are viewable by everyone" ON gifts FOR SELECT USING (true);
CREATE POLICY "Users can send gifts" ON gifts FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Follows: visibles par tous, seul le follower peut gérer
CREATE POLICY "Follows are viewable by everyone" ON follows FOR SELECT USING (true);
CREATE POLICY "Users can follow others" ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow" ON follows FOR DELETE USING (auth.uid() = follower_id);

-- ===============================
-- DONNÉES DE TEST (OPTIONNEL)
-- ===============================

-- Insérer des catégories par défaut si nécessaire
-- INSERT INTO categories (name) VALUES 
-- ('Général'), ('Gaming'), ('Musique'), ('Art'), ('Sport'), 
-- ('Cuisine'), ('Tech'), ('Éducation'), ('Lifestyle')
-- ON CONFLICT DO NOTHING;

-- ===============================
-- COMMENTAIRES ET DOCUMENTATION
-- ===============================

-- Cette base de données supporte:
-- ✅ Authentification utilisateur avec Supabase Auth
-- ✅ Lives en temps réel avec viewers tracking
-- ✅ Chat en temps réel avec messages
-- ✅ Système de réactions et gifts
-- ✅ Système de followers
-- ✅ Modération avec signalements
-- ✅ Transactions de tokens
-- ✅ Recherche textuelle optimisée
-- ✅ RLS pour la sécurité
-- ✅ Triggers pour la cohérence des données
-- ✅ Index pour les performances