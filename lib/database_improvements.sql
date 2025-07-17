-- ===============================================
-- SCRIPT COMPLET DE BASE DE DONNÉES STREAMY
-- Version: 3.3 - Script Consolidé + Améliorations TikTok Style
-- Description: Installation complète pour l'application de streaming live
-- 
-- MISE À JOUR 3.3:
-- - Ajout des améliorations TikTok style (swipe navigation)
-- - Système de messagerie privée
-- - Système de -- Politiques pour user_blocks
CREATE POLICY "Users can view own blocks" ON user_blocks FOR SELECT 
  USING (auth.uid() = blocker_id);
CREATE POLICY "Users can insert own blocks" ON user_blocks FOR INSERT 
  WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Users can delete own blocks" ON user_blocks FOR DELETE 
  USING (auth.uid() = blocker_id);

-- Politiques pour token_transactions
CREATE POLICY "Users can view own transactions" ON token_transactions FOR SELECT 
  USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own transactions" ON token_transactions FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- Politiques pour gift_events
CREATE POLICY "Gift events are viewable by everyone" ON gift_events FOR SELECT 
  USING (is_active = true);
CREATE POLICY "Moderators can manage gift events" ON gift_events FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND is_moderator = true
    )
  );

-- ===============================
-- DONNÉES DE TEST ET CONFIGURATION
-- ===============================llow amélioré
-- - Tables de cadeaux virtuels
-- - Correction des erreurs de table manquantes
-- ===============================================

-- Activer les extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===============================================
-- CORRECTIONS DE STRUCTURE
-- ===============================================

-- Ajouter la colonne gift_count à la table lives si elle n'existe pas
ALTER TABLE lives ADD COLUMN IF NOT EXISTS gift_count INTEGER DEFAULT 0;

-- ===============================================
-- NOUVELLES TABLES POUR LES AMÉLIORATIONS
-- ===============================================

-- Table pour les types de cadeaux
CREATE TABLE IF NOT EXISTS gift_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  emoji TEXT NOT NULL,
  cost INTEGER NOT NULL,
  rarity TEXT NOT NULL CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
  animation_data JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table pour les analyses de swipe (TikTok style)
CREATE TABLE IF NOT EXISTS swipe_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  from_live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  to_live_id UUID REFERENCES lives(id) ON DELETE CASCADE,
  direction TEXT NOT NULL CHECK (direction IN ('up', 'down', 'left', 'right')),
  time_spent_seconds INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table pour les conversations privées
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participant1_id UUID REFERENCES users(id) ON DELETE CASCADE,
  participant2_id UUID REFERENCES users(id) ON DELETE CASCADE,
  last_message TEXT,
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(participant1_id, participant2_id)
);

-- Table pour les messages privés
CREATE TABLE IF NOT EXISTS private_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  media_url TEXT,
  media_type TEXT,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP WITH TIME ZONE
);

-- Table pour le blocage d'utilisateurs
CREATE TABLE IF NOT EXISTS user_blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  blocker_id UUID REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(blocker_id, blocked_id)
);

-- Table pour les followers (améliorée)
CREATE TABLE IF NOT EXISTS user_follows (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(follower_id, following_id)
);

-- Table pour les transactions de tokens
CREATE TABLE IF NOT EXISTS token_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  package_id TEXT,
  tokens_amount INTEGER NOT NULL,
  price DECIMAL(10,2),
  payment_method TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('purchase', 'gift', 'reward', 'refund')),
  status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')) DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table pour les événements de cadeaux spéciaux
CREATE TABLE IF NOT EXISTS gift_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL CHECK (type IN ('bonus_multiplier', 'bonus_flat', 'discount')),
  multiplier DECIMAL(4,2) DEFAULT 1.0,
  bonus_amount INTEGER DEFAULT 0,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- ===============================
-- FONCTIONS POUR LES FOLLOWS
-- ===============================

-- Fonction pour incrémenter le nombre de followers
CREATE OR REPLACE FUNCTION increment_follower_count(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE users 
  SET followers = followers + 1, updated_at = now()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour décrémenter le nombre de followers
CREATE OR REPLACE FUNCTION decrement_follower_count(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE users 
  SET followers = GREATEST(followers - 1, 0), updated_at = now()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour incrémenter le nombre de following
CREATE OR REPLACE FUNCTION increment_following_count(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE users 
  SET following = following + 1, updated_at = now()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour décrémenter le nombre de following
CREATE OR REPLACE FUNCTION decrement_following_count(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE users 
  SET following = GREATEST(following - 1, 0), updated_at = now()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- ===============================
-- FONCTIONS POUR LES RECOMMANDATIONS
-- ===============================

-- Fonction pour obtenir des lives recommandés
CREATE OR REPLACE FUNCTION get_recommended_lives(user_id UUID, limit_count INTEGER)
RETURNS TABLE(
  id UUID,
  title TEXT,
  description TEXT,
  host_id UUID,
  host_name TEXT,
  host_avatar TEXT,
  category TEXT,
  thumbnail TEXT,
  viewer_count INTEGER,
  like_count INTEGER,
  gift_count INTEGER,
  is_live BOOLEAN,
  started_at TIMESTAMP WITH TIME ZONE,
  agora_channel_id TEXT,
  agora_token TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    l.id,
    l.title,
    l.description,
    l.host_id,
    u.full_name as host_name,
    u.avatar as host_avatar,
    l.category,
    l.thumbnail,
    l.viewer_count,
    l.like_count,
    l.gift_count,
    l.is_live,
    l.started_at,
    l.agora_channel_id,
    l.agora_token
  FROM lives l
  JOIN users u ON l.host_id = u.id
  WHERE l.is_live = true
    AND l.host_id != user_id
  ORDER BY 
    -- Prioriser les lives des personnes suivies
    CASE WHEN EXISTS(
      SELECT 1 FROM user_follows uf 
      WHERE uf.follower_id = user_id AND uf.following_id = l.host_id
    ) THEN 0 ELSE 1 END,
    l.viewer_count DESC,
    l.started_at DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour obtenir des utilisateurs suggérés
CREATE OR REPLACE FUNCTION get_suggested_users(current_user_id UUID, limit_count INTEGER)
RETURNS TABLE(
  id UUID,
  email TEXT,
  username TEXT,
  full_name TEXT,
  avatar TEXT,
  bio TEXT,
  followers INTEGER,
  following INTEGER,
  total_likes INTEGER,
  total_gifts INTEGER,
  tokens_balance INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  last_seen TIMESTAMP WITH TIME ZONE,
  is_verified BOOLEAN,
  is_moderator BOOLEAN,
  preferences JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.username,
    u.full_name,
    u.avatar,
    u.bio,
    u.followers,
    u.following,
    u.total_likes,
    u.total_gifts,
    u.tokens_balance,
    u.created_at,
    u.last_seen,
    u.is_verified,
    u.is_moderator,
    u.preferences
  FROM users u
  WHERE u.id != current_user_id
    AND u.id NOT IN (
      SELECT following_id FROM user_follows WHERE follower_id = current_user_id
    )
    AND u.id NOT IN (
      SELECT blocked_id FROM user_blocks WHERE blocker_id = current_user_id
    )
  ORDER BY 
    u.followers DESC,
    u.last_seen DESC NULLS LAST
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour obtenir des stats de recherche
CREATE OR REPLACE FUNCTION get_search_stats()
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_users', (SELECT COUNT(*) FROM users),
    'verified_users', (SELECT COUNT(*) FROM users WHERE is_verified = true),
    'active_users', (SELECT COUNT(*) FROM users WHERE last_seen > NOW() - INTERVAL '24 hours')
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ===============================
-- INDEX POUR LES PERFORMANCES
-- ===============================

-- Index pour swipe_analytics
CREATE INDEX IF NOT EXISTS idx_swipe_analytics_user_id ON swipe_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_swipe_analytics_created_at ON swipe_analytics(created_at DESC);

-- Index pour conversations
CREATE INDEX IF NOT EXISTS idx_conversations_participant1 ON conversations(participant1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant2 ON conversations(participant2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON conversations(last_message_at DESC);

-- Index pour private_messages
CREATE INDEX IF NOT EXISTS idx_private_messages_conversation ON private_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_private_messages_sender ON private_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_private_messages_recipient ON private_messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_private_messages_sent_at ON private_messages(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_private_messages_unread ON private_messages(recipient_id, is_read) WHERE is_read = false;

-- Index pour user_follows
CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_following ON user_follows(following_id);

-- Index pour user_blocks
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);

-- Index pour token_transactions
CREATE INDEX IF NOT EXISTS idx_token_transactions_user_id ON token_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_token_transactions_created_at ON token_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_transactions_status ON token_transactions(status);

-- Index pour gift_events
CREATE INDEX IF NOT EXISTS idx_gift_events_dates ON gift_events(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_gift_events_active ON gift_events(is_active);

-- ===============================
-- POLITIQUES DE SÉCURITÉ RLS
-- ===============================

-- Activer RLS sur les nouvelles tables
ALTER TABLE swipe_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE gift_events ENABLE ROW LEVEL SECURITY;

-- Politiques pour swipe_analytics
CREATE POLICY "Users can insert own analytics" ON swipe_analytics FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view own analytics" ON swipe_analytics FOR SELECT USING (auth.uid() = user_id);

-- Politiques pour conversations
CREATE POLICY "Users can view own conversations" ON conversations FOR SELECT 
  USING (auth.uid() = participant1_id OR auth.uid() = participant2_id);
CREATE POLICY "Users can insert conversations" ON conversations FOR INSERT 
  WITH CHECK (auth.uid() = participant1_id OR auth.uid() = participant2_id);
CREATE POLICY "Users can update own conversations" ON conversations FOR UPDATE 
  USING (auth.uid() = participant1_id OR auth.uid() = participant2_id);

-- Politiques pour private_messages
CREATE POLICY "Users can view own messages" ON private_messages FOR SELECT 
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
CREATE POLICY "Users can insert own messages" ON private_messages FOR INSERT 
  WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Users can update own messages" ON private_messages FOR UPDATE 
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Politiques pour user_follows
CREATE POLICY "Users can view all follows" ON user_follows FOR SELECT USING (true);
CREATE POLICY "Users can insert own follows" ON user_follows FOR INSERT 
  WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can delete own follows" ON user_follows FOR DELETE 
  USING (auth.uid() = follower_id);

-- Politiques pour user_blocks
CREATE POLICY "Users can view own blocks" ON user_blocks FOR SELECT 
  USING (auth.uid() = blocker_id);
CREATE POLICY "Users can insert own blocks" ON user_blocks FOR INSERT 
  WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Users can delete own blocks" ON user_blocks FOR DELETE 
  USING (auth.uid() = blocker_id);

-- ===============================
-- DONNÉES DE TEST
-- ===============================

-- ===============================
-- FONCTIONS POUR LES TOKENS
-- ===============================

-- Fonction pour débiter des tokens
CREATE OR REPLACE FUNCTION debit_tokens(user_id UUID, amount INTEGER)
RETURNS VOID AS $$
DECLARE
  current_balance INTEGER;
BEGIN
  -- Vérifier le solde actuel
  SELECT tokens_balance INTO current_balance
  FROM users 
  WHERE id = user_id;
  
  IF current_balance IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  
  IF current_balance < amount THEN
    RAISE EXCEPTION 'Insufficient token balance';
  END IF;
  
  -- Débiter les tokens
  UPDATE users 
  SET tokens_balance = tokens_balance - amount,
      updated_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour créditer des tokens
CREATE OR REPLACE FUNCTION credit_tokens(user_id UUID, amount INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE users 
  SET tokens_balance = tokens_balance + amount,
      updated_at = NOW()
  WHERE id = user_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour incrémenter le compteur de gifts d'un live
CREATE OR REPLACE FUNCTION increment_gift_count(live_id UUID, gift_count INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE lives 
  SET gift_count = COALESCE(lives.gift_count, 0) + increment_gift_count.gift_count,
      updated_at = NOW()
  WHERE id = live_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Live not found';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ===============================
-- FONCTIONS POUR LES CADEAUX
-- ===============================

-- Fonction pour envoyer un cadeau améliorée
CREATE OR REPLACE FUNCTION send_gift_enhanced(
  p_live_id UUID,
  p_sender_id UUID,
  p_receiver_id UUID,
  p_gift_type_id UUID,
  p_quantity INTEGER DEFAULT 1
)
RETURNS UUID AS $$
DECLARE
  gift_id UUID;
  gift_cost INTEGER;
  sender_balance INTEGER;
  sender_name TEXT;
  sender_avatar TEXT;
  gift_name TEXT;
  gift_emoji TEXT;
BEGIN
  -- Récupérer les informations du cadeau
  SELECT cost, name, emoji INTO gift_cost, gift_name, gift_emoji
  FROM gift_types 
  WHERE id = p_gift_type_id AND is_active = true;
  
  IF gift_cost IS NULL THEN
    RAISE EXCEPTION 'Invalid gift type';
  END IF;
  
  gift_cost := gift_cost * p_quantity;
  
  -- Vérifier le solde de l'expéditeur
  SELECT tokens_balance, username, avatar 
  INTO sender_balance, sender_name, sender_avatar
  FROM users 
  WHERE id = p_sender_id;
  
  IF sender_balance < gift_cost THEN
    RAISE EXCEPTION 'Insufficient tokens balance';
  END IF;
  
  -- Débiter l'expéditeur
  UPDATE users 
  SET tokens_balance = tokens_balance - gift_cost
  WHERE id = p_sender_id;
  
  -- Créditer le receveur (50% de la valeur)
  UPDATE users 
  SET 
    tokens_balance = tokens_balance + (gift_cost / 2),
    total_gifts = total_gifts + p_quantity
  WHERE id = p_receiver_id;
  
  -- Enregistrer le cadeau dans la table gifts
  INSERT INTO gifts (
    live_id, 
    sender_id, 
    sender_name, 
    sender_avatar,
    receiver_id, 
    gift_type, 
    quantity, 
    total_cost
  ) VALUES (
    p_live_id, 
    p_sender_id, 
    sender_name, 
    sender_avatar,
    p_receiver_id, 
    gift_name, 
    p_quantity, 
    gift_cost
  ) RETURNING id INTO gift_id;
  
  -- Ajouter un message de cadeau au chat
  INSERT INTO live_messages (
    live_id, 
    user_id, 
    user_name, 
    user_avatar, 
    content, 
    type,
    metadata
  ) VALUES (
    p_live_id,
    p_sender_id,
    sender_name,
    sender_avatar,
    format('%s a envoyé %s %s %s', sender_name, p_quantity, gift_emoji, gift_name),
    'gift',
    jsonb_build_object(
      'gift_id', gift_id,
      'gift_type', gift_name,
      'quantity', p_quantity,
      'cost', gift_cost
    )
  );
  
  RETURN gift_id;
END;
$$ LANGUAGE plpgsql;

-- ===============================
-- DONNÉES DE TEST ET CONFIGURATION
-- ===============================

-- Ajouter quelques types de cadeaux par défaut
INSERT INTO gift_types (name, emoji, cost, rarity, animation_data, is_active) VALUES
('rose', '🌹', 10, 'common', '{"duration": 1000, "effect": "sparkle"}', true),
('diamant', '💎', 100, 'rare', '{"duration": 2000, "effect": "shine"}', true),
('cadeau', '🎁', 50, 'common', '{"duration": 1500, "effect": "bounce"}', true),
('couronne', '👑', 500, 'epic', '{"duration": 3000, "effect": "royal"}', true),
('voiture', '🚗', 1000, 'epic', '{"duration": 2500, "effect": "speed"}', true),
('maison', '🏠', 5000, 'legendary', '{"duration": 4000, "effect": "luxury"}', true)
ON CONFLICT (name) DO NOTHING;

-- ===============================
-- TRIGGERS POUR LES NOUVELLES TABLES
-- ===============================

-- Trigger pour mettre à jour les stats de followers
CREATE OR REPLACE FUNCTION update_follow_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Incrémenter following pour le follower
    PERFORM increment_following_count(NEW.follower_id);
    -- Incrémenter followers pour le suivi
    PERFORM increment_follower_count(NEW.following_id);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Décrémenter following pour le follower
    PERFORM decrement_following_count(OLD.follower_id);
    -- Décrémenter followers pour le suivi
    PERFORM decrement_follower_count(OLD.following_id);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger pour les follows
DROP TRIGGER IF EXISTS trigger_update_follow_stats ON user_follows;
CREATE TRIGGER trigger_update_follow_stats
  AFTER INSERT OR DELETE ON user_follows
  FOR EACH ROW EXECUTE FUNCTION update_follow_stats();

-- ===============================
-- POLITIQUES RLS POUR LES GIFT_TYPES
-- ===============================

-- Activer RLS sur gift_types
ALTER TABLE gift_types ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre la lecture à tous
CREATE POLICY "Gift types are viewable by everyone" ON gift_types
  FOR SELECT USING (is_active = true);

-- Politique pour permettre aux modérateurs de gérer les types de cadeaux
CREATE POLICY "Moderators can manage gift types" ON gift_types
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND is_moderator = true
    )
  );

-- ===============================
-- INDEX POUR LES GIFT_TYPES
-- ===============================

CREATE INDEX IF NOT EXISTS idx_gift_types_name ON gift_types(name);
CREATE INDEX IF NOT EXISTS idx_gift_types_cost ON gift_types(cost);
CREATE INDEX IF NOT EXISTS idx_gift_types_rarity ON gift_types(rarity);
CREATE INDEX IF NOT EXISTS idx_gift_types_active ON gift_types(is_active);

-- ===============================
-- COMMENTAIRES DE DOCUMENTATION
-- ===============================

COMMENT ON TABLE gift_types IS 'Types de cadeaux virtuels disponibles dans l''application';
COMMENT ON TABLE swipe_analytics IS 'Analyse des swipes pour recommandations TikTok-style';
COMMENT ON TABLE conversations IS 'Conversations privées entre utilisateurs';
COMMENT ON TABLE private_messages IS 'Messages privés dans les conversations';
COMMENT ON TABLE user_blocks IS 'Liste des utilisateurs bloqués';
COMMENT ON TABLE token_transactions IS 'Historique des transactions de tokens';
COMMENT ON TABLE gift_events IS 'Événements spéciaux pour les cadeaux (bonus, promotions)';

-- ===============================
-- SCRIPT TERMINÉ AVEC SUCCÈS
-- Version 3.3 - TikTok Style Improvements + Gift System
-- 
-- NOUVELLES FONCTIONNALITÉS AJOUTÉES:
-- ✅ Système de cadeaux virtuels complet
-- ✅ Transactions de tokens sécurisées
-- ✅ Événements spéciaux et promotions
-- ✅ Analytics de swipe TikTok-style
-- ✅ Messagerie privée
-- ✅ Système de follow/unfollow
-- ✅ Fonctions RPC pour les opérations critiques
-- ===============================
