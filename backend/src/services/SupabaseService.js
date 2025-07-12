const { createClient } = require('@supabase/supabase-js');
const config = require('../config');

class SupabaseService {
  constructor() {
    // Client avec clé anonyme pour les opérations publiques
    this.supabase = createClient(config.supabase.url, config.supabase.anonKey);
    
    // Client avec clé service pour les opérations admin
    this.supabaseAdmin = config.supabase.serviceRoleKey 
      ? createClient(config.supabase.url, config.supabase.serviceRoleKey)
      : null;
  }

  /**
   * Créer un nouveau live stream
   */
  async createLiveStream(liveData) {
    try {
      const { data, error } = await this.supabase
        .from('lives')
        .insert(liveData)
        .select()
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Erreur création live:', error);
      throw new Error(`Impossible de créer le live: ${error.message}`);
    }
  }

  /**
   * Récupérer les lives actifs
   */
  async getActiveLives(limit = 20, offset = 0) {
    try {
      const { data, error } = await this.supabase
        .from('lives')
        .select(`
          *,
          users (
            id,
            username,
            full_name,
            avatar
          )
        `)
        .eq('is_live', true)
        .order('viewer_count', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Erreur récupération lives:', error);
      throw new Error(`Impossible de récupérer les lives: ${error.message}`);
    }
  }

  /**
   * Récupérer un live par son ID
   */
  async getLiveById(liveId) {
    try {
      const { data, error } = await this.supabase
        .from('lives')
        .select(`
          *,
          users (
            id,
            username,
            full_name,
            avatar
          )
        `)
        .eq('id', liveId)
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Erreur récupération live:', error);
      throw new Error(`Live non trouvé: ${error.message}`);
    }
  }

  /**
   * Mettre à jour un live
   */
  async updateLive(liveId, updates) {
    try {
      const { data, error } = await this.supabase
        .from('lives')
        .update(updates)
        .eq('id', liveId)
        .select()
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Erreur mise à jour live:', error);
      throw new Error(`Impossible de mettre à jour le live: ${error.message}`);
    }
  }

  /**
   * Terminer un live
   */
  async endLive(liveId) {
    try {
      const updates = {
        is_live: false,
        ended_at: new Date().toISOString(),
      };

      return await this.updateLive(liveId, updates);
    } catch (error) {
      console.error('Erreur fin live:', error);
      throw new Error(`Impossible de terminer le live: ${error.message}`);
    }
  }

  /**
   * Incrémenter le nombre de viewers
   */
  async incrementViewerCount(liveId) {
    try {
      const { data, error } = await this.supabase
        .rpc('increment_viewer_count', { live_id: liveId });

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Erreur incrémentation viewers:', error);
      // Ne pas lever d'erreur pour ne pas bloquer l'utilisateur
      return false;
    }
  }

  /**
   * Décrémenter le nombre de viewers
   */
  async decrementViewerCount(liveId) {
    try {
      const { data, error } = await this.supabase
        .rpc('decrement_viewer_count', { live_id: liveId });

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Erreur décrémentation viewers:', error);
      return false;
    }
  }

  /**
   * Créer un profil utilisateur
   */
  async createUserProfile(userData) {
    try {
      const { data, error } = await this.supabase
        .from('users')
        .insert(userData)
        .select()
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Erreur création profil:', error);
      throw new Error(`Impossible de créer le profil: ${error.message}`);
    }
  }

  /**
   * Récupérer un profil utilisateur
   */
  async getUserProfile(userId) {
    try {
      const { data, error } = await this.supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Erreur récupération profil:', error);
      return null;
    }
  }

  /**
   * Envoyer un message dans un live
   */
  async sendMessage(messageData) {
    try {
      const { data, error } = await this.supabase
        .from('live_messages')
        .insert(messageData)
        .select()
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Erreur envoi message:', error);
      throw new Error(`Impossible d'envoyer le message: ${error.message}`);
    }
  }

  /**
   * Récupérer les messages d'un live
   */
  async getLiveMessages(liveId, limit = 50) {
    try {
      const { data, error } = await this.supabase
        .from('live_messages')
        .select('*')
        .eq('live_id', liveId)
        .order('created_at', { ascending: false })
        .limit(limit);

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Erreur récupération messages:', error);
      throw new Error(`Impossible de récupérer les messages: ${error.message}`);
    }
  }

  /**
   * Vérifier la santé de la connexion Supabase
   */
  async checkHealth() {
    try {
      const { data, error } = await this.supabase
        .from('lives')
        .select('count(*)')
        .limit(1);

      if (error) throw error;
      
      return {
        success: true,
        url: config.supabase.url,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        timestamp: new Date().toISOString(),
      };
    }
  }
}

module.exports = SupabaseService;
