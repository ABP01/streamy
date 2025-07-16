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


-- Migration pour ajouter les colonnes Agora manquantes
-- Exécuter ces commandes dans Supabase SQL Editor

-- Ajouter la colonne agora_channel_id
ALTER TABLE lives 
ADD COLUMN IF NOT EXISTS agora_channel_id VARCHAR(255);

-- Ajouter la colonne agora_token
ALTER TABLE lives 
ADD COLUMN IF NOT EXISTS agora_token TEXT;

-- Mettre à jour les enregistrements existants
UPDATE lives 
SET agora_channel_id = CONCAT('live_', id)
WHERE agora_channel_id IS NULL;


-- Script d'optimisation de la base de données pour les nouvelles fonctionnalités Streamy
-- Date: 2025-07-12

-- ===============================
-- AMÉLIORATIONS POUR AUTO-JOIN ET CHAT FLOTTANT
-- ===============================

-- Table pour tracker l'historique des auto-joins
CREATE TABLE IF NOT EXISTS auto_join_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  left_at TIMESTAMP WITH TIME ZONE,
  scroll_direction TEXT, -- 'up', 'down'
  session_duration INTEGER DEFAULT 0, -- en secondes
  UNIQUE(user_id, live_id, joined_at)
);

-- Table pour les messages de chat avec animation et opacité
ALTER TABLE live_messages 
ADD COLUMN IF NOT EXISTS display_duration INTEGER DEFAULT 8,
ADD COLUMN IF NOT EXISTS animation_type TEXT DEFAULT 'slide_up',
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 1;

-- ===============================
-- AMÉLIORATIONS POUR LE SYSTÈME DE CADEAUX
-- ===============================

-- Table des types de cadeaux disponibles
CREATE TABLE IF NOT EXISTS gift_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  emoji TEXT NOT NULL,
  cost INTEGER NOT NULL,
  rarity TEXT DEFAULT 'common', -- 'common', 'rare', 'epic', 'legendary'
  animation_data JSONB,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Insérer les types de cadeaux par défaut
INSERT INTO gift_types (name, emoji, cost, rarity, animation_data) VALUES 
('Rose', '🌹', 1, 'common', '{"duration": 2000, "effect": "float"}'),
('Coeur', '❤️', 2, 'common', '{"duration": 2500, "effect": "pulse"}'),
('Cadeau', '🎁', 5, 'rare', '{"duration": 3000, "effect": "bounce"}'),
('Diamant', '💎', 10, 'epic', '{"duration": 4000, "effect": "sparkle"}'),
('Couronne', '👑', 25, 'epic', '{"duration": 5000, "effect": "royal"}'),
('Fusée', '🚀', 50, 'legendary', '{"duration": 6000, "effect": "rocket"}')
ON CONFLICT (name) DO NOTHING;

-- Modifier la table gifts pour référencer gift_types
ALTER TABLE gifts 
ADD COLUMN IF NOT EXISTS gift_type_id UUID REFERENCES gift_types(id),
ADD COLUMN IF NOT EXISTS gift_animation_data JSONB,
ADD COLUMN IF NOT EXISTS display_position JSONB; -- {x: number, y: number}

-- ===============================
-- AMÉLIORATIONS POUR LES RÉACTIONS
-- ===============================

-- Table des types de réactions
CREATE TABLE IF NOT EXISTS reaction_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  emoji TEXT NOT NULL,
  animation_data JSONB,
  is_active BOOLEAN DEFAULT TRUE
);

-- Insérer les types de réactions par défaut
INSERT INTO reaction_types (name, emoji, animation_data) VALUES 
('heart', '❤️', '{"duration": 3000, "path": "floating", "scale": [0.5, 1.2, 0.8]}'),
('like', '👍', '{"duration": 2000, "path": "bounce", "scale": [1.0, 1.5, 1.0]}'),
('fire', '🔥', '{"duration": 2500, "path": "flicker", "scale": [0.8, 1.3, 1.0]}'),
('star', '⭐', '{"duration": 3500, "path": "sparkle", "scale": [0.3, 1.0, 0.7]}')
ON CONFLICT (name) DO NOTHING;

-- Modifier la table reactions
ALTER TABLE reactions 
ADD COLUMN IF NOT EXISTS reaction_type_id UUID REFERENCES reaction_types(id),
ADD COLUMN IF NOT EXISTS animation_data JSONB,
ADD COLUMN IF NOT EXISTS trigger_type TEXT DEFAULT 'tap'; -- 'tap', 'double_tap', 'long_press'

-- ===============================
-- VUES OPTIMISÉES POUR L'INTERFACE
-- ===============================

-- Vue pour les lives avec informations complètes
CREATE OR REPLACE VIEW live_streams_view AS
SELECT 
  l.id,
  l.title,
  l.description,
  l.category,
  l.thumbnail,
  l.viewer_count,
  l.like_count,
  l.gift_count,
  l.is_live,
  l.started_at,
  l.agora_channel_id,
  l.agora_token,
  u.username,
  u.full_name,
  u.avatar as user_avatar,
  u.is_verified,
  -- Calcul de la durée du live
  CASE 
    WHEN l.is_live THEN EXTRACT(EPOCH FROM (NOW() - l.started_at))::INTEGER
    ELSE 0
  END as duration_seconds,
  -- Statistiques récentes
  (SELECT COUNT(*) FROM live_messages WHERE live_id = l.id AND created_at > NOW() - INTERVAL '5 minutes') as recent_message_count,
  (SELECT COUNT(*) FROM reactions WHERE live_id = l.id AND created_at > NOW() - INTERVAL '1 minute') as recent_reaction_count
FROM lives l
JOIN users u ON l.host_id = u.id
WHERE l.is_live = true
ORDER BY l.viewer_count DESC, l.started_at DESC;

-- Vue pour les messages de chat avec animation
CREATE OR REPLACE VIEW chat_messages_view AS
SELECT 
  lm.id,
  lm.live_id,
  lm.content,
  lm.user_name,
  lm.user_avatar,
  lm.display_duration,
  lm.animation_type,
  lm.priority,
  lm.created_at,
  -- Calcul de l'âge du message pour l'opacité
  EXTRACT(EPOCH FROM (NOW() - lm.created_at))::INTEGER as age_seconds,
  -- Calcul de l'opacité basée sur l'âge
  CASE 
    WHEN EXTRACT(EPOCH FROM (NOW() - lm.created_at)) < lm.display_duration THEN 1.0
    ELSE GREATEST(0.0, 1.0 - (EXTRACT(EPOCH FROM (NOW() - lm.created_at)) - lm.display_duration) / 4.0)
  END as opacity
FROM live_messages lm
WHERE lm.created_at > NOW() - INTERVAL '30 seconds'
ORDER BY lm.created_at DESC;

-- ===============================
-- FONCTIONS POUR LES NOUVELLES FONCTIONNALITÉS
-- ===============================

-- Fonction pour auto-join un live
CREATE OR REPLACE FUNCTION auto_join_live(p_user_id UUID, p_live_id UUID, p_scroll_direction TEXT)
RETURNS VOID AS $$
BEGIN
  -- Terminer la session précédente si elle existe
  UPDATE auto_join_history 
  SET left_at = NOW(),
      session_duration = EXTRACT(EPOCH FROM (NOW() - joined_at))::INTEGER
  WHERE user_id = p_user_id AND left_at IS NULL;
  
  -- Créer une nouvelle session
  INSERT INTO auto_join_history (user_id, live_id, scroll_direction)
  VALUES (p_user_id, p_live_id, p_scroll_direction);
  
  -- Incrémenter le compteur de viewers
  PERFORM increment_viewer_count(p_live_id);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour auto-leave un live
CREATE OR REPLACE FUNCTION auto_leave_live(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
  v_live_id UUID;
BEGIN
  -- Récupérer le live actuel
  SELECT live_id INTO v_live_id
  FROM auto_join_history 
  WHERE user_id = p_user_id AND left_at IS NULL
  LIMIT 1;
  
  IF v_live_id IS NOT NULL THEN
    -- Terminer la session
    UPDATE auto_join_history 
    SET left_at = NOW(),
        session_duration = EXTRACT(EPOCH FROM (NOW() - joined_at))::INTEGER
    WHERE user_id = p_user_id AND left_at IS NULL;
    
    -- Décrémenter le compteur de viewers
    PERFORM decrement_viewer_count(v_live_id);
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour envoyer un cadeau
CREATE OR REPLACE FUNCTION send_gift(
  p_sender_id UUID,
  p_live_id UUID,
  p_gift_type_name TEXT,
  p_quantity INTEGER DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
  v_gift_type gift_types%ROWTYPE;
  v_total_cost INTEGER;
  v_sender_balance INTEGER;
  v_receiver_id UUID;
  v_gift_id UUID;
BEGIN
  -- Récupérer le destinataire (host du live)
  SELECT host_id INTO v_receiver_id FROM lives WHERE id = p_live_id;
  
  -- Vérifier que l'expéditeur n'est pas l'hôte du live
  IF p_sender_id = v_receiver_id THEN
    RETURN '{"success": false, "error": "Host cannot send gifts in their own live"}'::JSONB;
  END IF;
  
  -- Récupérer les informations du cadeau
  SELECT * INTO v_gift_type FROM gift_types WHERE name = p_gift_type_name AND is_active = true;
  IF NOT FOUND THEN
    RETURN '{"success": false, "error": "Gift type not found"}'::JSONB;
  END IF;
  
  -- Calculer le coût total
  v_total_cost := v_gift_type.cost * p_quantity;
  
  -- Vérifier le solde de l'expéditeur
  SELECT tokens_balance INTO v_sender_balance FROM users WHERE id = p_sender_id;
  IF v_sender_balance < v_total_cost THEN
    RETURN '{"success": false, "error": "Insufficient balance"}'::JSONB;
  END IF;
  
  -- Débiter les tokens de l'expéditeur
  PERFORM debit_tokens(p_sender_id, v_total_cost);
  
  -- Créditer 80% des tokens au destinataire (20% commission plateforme)
  PERFORM credit_tokens(v_receiver_id, (v_total_cost * 0.8)::INTEGER);
  
  -- Enregistrer le cadeau
  INSERT INTO gifts (live_id, sender_id, receiver_id, gift_type_id, quantity, total_cost, gift_animation_data)
  VALUES (p_live_id, p_sender_id, v_receiver_id, v_gift_type.id, p_quantity, v_total_cost, v_gift_type.animation_data)
  RETURNING id INTO v_gift_id;
  
  -- Enregistrer les transactions
  INSERT INTO token_transactions (user_id, amount, type, reference_id)
  VALUES 
    (p_sender_id, -v_total_cost, 'gift_sent', v_gift_id),
    (v_receiver_id, (v_total_cost * 0.8)::INTEGER, 'gift_received', v_gift_id);
  
  -- Incrémenter le compteur de cadeaux du live
  PERFORM increment_gift_count(p_live_id, p_quantity);
  
  RETURN jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'total_cost', v_total_cost,
    'animation_data', v_gift_type.animation_data
  );
END;
$$ LANGUAGE plpgsql;

-- ===============================
-- INDEX POUR LES NOUVELLES TABLES
-- ===============================

-- Index pour auto_join_history
CREATE INDEX IF NOT EXISTS idx_auto_join_history_user_id ON auto_join_history(user_id);
CREATE INDEX IF NOT EXISTS idx_auto_join_history_live_id ON auto_join_history(live_id);
CREATE INDEX IF NOT EXISTS idx_auto_join_history_joined_at ON auto_join_history(joined_at DESC);

-- Index pour gift_types
CREATE INDEX IF NOT EXISTS idx_gift_types_cost ON gift_types(cost);
CREATE INDEX IF NOT EXISTS idx_gift_types_rarity ON gift_types(rarity);

-- Index pour reaction_types
CREATE INDEX IF NOT EXISTS idx_reaction_types_name ON reaction_types(name);

-- ===============================
-- POLITIQUES RLS POUR LES NOUVELLES TABLES
-- ===============================

-- Auto join history
ALTER TABLE auto_join_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own auto join history" ON auto_join_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own auto join history" ON auto_join_history FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own auto join history" ON auto_join_history FOR UPDATE USING (auth.uid() = user_id);

-- Gift types (lecture seule pour tous)
ALTER TABLE gift_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Gift types are viewable by everyone" ON gift_types FOR SELECT USING (true);

-- Reaction types (lecture seule pour tous)
ALTER TABLE reaction_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Reaction types are viewable by everyone" ON reaction_types FOR SELECT USING (true);

-- ===============================
-- TRIGGERS POUR LES NOUVELLES FONCTIONNALITÉS
-- ===============================

-- Trigger pour nettoyer automatiquement les anciennes sessions auto-join
CREATE OR REPLACE FUNCTION cleanup_old_auto_join_sessions()
RETURNS TRIGGER AS $$
BEGIN
  -- Nettoyer les sessions de plus de 24h
  DELETE FROM auto_join_history 
  WHERE joined_at < NOW() - INTERVAL '24 hours'
    AND left_at IS NOT NULL;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cleanup_auto_join_sessions_trigger
AFTER INSERT ON auto_join_history
FOR EACH STATEMENT
EXECUTE FUNCTION cleanup_old_auto_join_sessions();

-- ===============================
-- VUES POUR LES STATISTIQUES
-- ===============================

-- Vue pour les statistiques des cadeaux
CREATE OR REPLACE VIEW gift_statistics AS
SELECT 
  gt.name as gift_name,
  gt.emoji,
  gt.cost,
  gt.rarity,
  COUNT(g.id) as total_sent,
  SUM(g.quantity) as total_quantity,
  SUM(g.total_cost) as total_revenue,
  AVG(g.total_cost) as avg_cost_per_gift
FROM gift_types gt
LEFT JOIN gifts g ON gt.id = g.gift_type_id
GROUP BY gt.id, gt.name, gt.emoji, gt.cost, gt.rarity
ORDER BY total_revenue DESC;

-- Vue pour les statistiques d'auto-join
CREATE OR REPLACE VIEW auto_join_statistics AS
SELECT 
  l.id as live_id,
  l.title,
  COUNT(ajh.id) as total_auto_joins,
  AVG(ajh.session_duration) as avg_session_duration,
  COUNT(CASE WHEN ajh.scroll_direction = 'down' THEN 1 END) as scroll_down_joins,
  COUNT(CASE WHEN ajh.scroll_direction = 'up' THEN 1 END) as scroll_up_joins
FROM lives l
LEFT JOIN auto_join_history ajh ON l.id = ajh.live_id
WHERE l.is_live = true
GROUP BY l.id, l.title
ORDER BY total_auto_joins DESC;

-- ===============================
-- SYSTÈME DE CO-HOST COMME TIKTOK
-- ===============================

-- Table des demandes de co-host
CREATE TABLE IF NOT EXISTS cohost_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID NOT NULL REFERENCES lives(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  requester_name TEXT NOT NULL,
  requester_avatar TEXT,
  host_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'canceled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  responded_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(live_id, requester_id, status) -- Un utilisateur ne peut avoir qu'une demande pending par live
);

-- Table des co-hosts actifs
CREATE TABLE IF NOT EXISTS cohosts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  live_id UUID NOT NULL REFERENCES lives(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  is_active BOOLEAN DEFAULT TRUE,
  UNIQUE(live_id, user_id) -- Un utilisateur ne peut être co-host qu'une fois par live
);

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_cohost_requests_live_id ON cohost_requests(live_id);
CREATE INDEX IF NOT EXISTS idx_cohost_requests_host_id ON cohost_requests(host_id);
CREATE INDEX IF NOT EXISTS idx_cohost_requests_status ON cohost_requests(status);
CREATE INDEX IF NOT EXISTS idx_cohosts_live_id ON cohosts(live_id);
CREATE INDEX IF NOT EXISTS idx_cohosts_user_id ON cohosts(user_id);
CREATE INDEX IF NOT EXISTS idx_cohosts_active ON cohosts(is_active);

-- Fonction pour traiter une demande de co-host
CREATE OR REPLACE FUNCTION process_cohost_request(
  p_request_id UUID,
  p_host_id UUID,
  p_accept BOOLEAN
)
RETURNS JSONB AS $$
DECLARE
  v_request cohost_requests%ROWTYPE;
  v_status TEXT;
BEGIN
  -- Récupérer la demande
  SELECT * INTO v_request FROM cohost_requests 
  WHERE id = p_request_id AND host_id = p_host_id AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN '{"success": false, "error": "Request not found or already processed"}'::JSONB;
  END IF;
  
  -- Définir le statut
  v_status := CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END;
  
  -- Mettre à jour la demande
  UPDATE cohost_requests 
  SET status = v_status, responded_at = NOW()
  WHERE id = p_request_id;
  
  -- Si acceptée, créer l'entrée co-host
  IF p_accept THEN
    INSERT INTO cohosts (live_id, user_id, user_name, user_avatar, is_active)
    VALUES (v_request.live_id, v_request.requester_id, v_request.requester_name, v_request.requester_avatar, true)
    ON CONFLICT (live_id, user_id) DO UPDATE SET is_active = true;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'status', v_status,
    'cohost_created', p_accept
  );
END;
$$ LANGUAGE plpgsql;

-- Fonction pour retirer un co-host
CREATE OR REPLACE FUNCTION remove_cohost(
  p_live_id UUID,
  p_host_id UUID,
  p_cohost_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_live_host_id UUID;
BEGIN
  -- Vérifier que l'utilisateur est bien l'hôte du live
  SELECT host_id INTO v_live_host_id FROM lives WHERE id = p_live_id;
  
  IF v_live_host_id != p_host_id THEN
    RETURN '{"success": false, "error": "Only the host can remove co-hosts"}'::JSONB;
  END IF;
  
  -- Désactiver le co-host
  UPDATE cohosts 
  SET is_active = false
  WHERE live_id = p_live_id AND user_id = p_cohost_user_id;
  
  IF NOT FOUND THEN
    RETURN '{"success": false, "error": "Co-host not found"}'::JSONB;
  END IF;
  
  RETURN '{"success": true, "message": "Co-host removed successfully"}'::JSONB;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour nettoyer les anciennes demandes
CREATE OR REPLACE FUNCTION cleanup_old_cohost_requests()
RETURNS TRIGGER AS $$
BEGIN
  -- Supprimer les demandes de plus de 24h qui sont encore pending
  DELETE FROM cohost_requests 
  WHERE status = 'pending' 
  AND created_at < NOW() - INTERVAL '24 hours';
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger
DROP TRIGGER IF EXISTS trigger_cleanup_old_cohost_requests ON cohost_requests;
CREATE TRIGGER trigger_cleanup_old_cohost_requests
  AFTER INSERT ON cohost_requests
  EXECUTE FUNCTION cleanup_old_cohost_requests();

-- Vue pour les statistiques de co-host
CREATE OR REPLACE VIEW cohost_statistics AS
SELECT 
  l.id as live_id,
  l.title as live_title,
  l.host_id,
  COUNT(DISTINCT c.user_id) as active_cohosts_count,
  COUNT(DISTINCT cr.requester_id) as pending_requests_count,
  ARRAY_AGG(DISTINCT c.user_name) FILTER (WHERE c.is_active = true) as cohost_names
FROM lives l
LEFT JOIN cohosts c ON l.id = c.live_id AND c.is_active = true
LEFT JOIN cohost_requests cr ON l.id = cr.live_id AND cr.status = 'pending'
WHERE l.is_live = true
GROUP BY l.id, l.title, l.host_id;

-- Politiques RLS pour la sécurité
ALTER TABLE cohost_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE cohosts ENABLE ROW LEVEL SECURITY;

-- Les utilisateurs peuvent voir les demandes où ils sont concernés
CREATE POLICY "Users can view their own cohost requests" ON cohost_requests
  FOR SELECT USING (
    auth.uid()::text = requester_id::text OR 
    auth.uid()::text = host_id::text
  );

-- Les utilisateurs peuvent créer des demandes de co-host
CREATE POLICY "Users can create cohost requests" ON cohost_requests
  FOR INSERT WITH CHECK (auth.uid()::text = requester_id::text);

-- Les utilisateurs peuvent mettre à jour leurs propres demandes ou répondre aux demandes reçues
CREATE POLICY "Users can update cohost requests" ON cohost_requests
  FOR UPDATE USING (
    auth.uid()::text = requester_id::text OR 
    auth.uid()::text = host_id::text
  );

-- Les utilisateurs peuvent voir les co-hosts des lives
CREATE POLICY "Users can view cohosts" ON cohosts
  FOR SELECT USING (true);

-- Seul l'hôte peut créer des entrées de co-host
CREATE POLICY "Only hosts can create cohosts" ON cohosts
  FOR INSERT WITH CHECK (
    auth.uid()::text IN (
      SELECT host_id::text FROM lives WHERE id = live_id
    )
  );

-- Les hôtes et les co-hosts peuvent mettre à jour les entrées
CREATE POLICY "Hosts and cohosts can update" ON cohosts
  FOR UPDATE USING (
    auth.uid()::text = user_id::text OR
    auth.uid()::text IN (
      SELECT host_id::text FROM lives WHERE id = live_id
    )
  );

-- ===============================
-- FIN DU SYSTÈME DE CO-HOST
-- ===============================
