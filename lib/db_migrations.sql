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
