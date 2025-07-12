const SupabaseService = require('../services/SupabaseService');

class LiveController {
  constructor() {
    this.supabaseService = new SupabaseService();
  }

  /**
   * Récupérer tous les lives actifs
   * GET /api/lives
   */
  async getLives(req, res) {
    try {
      const { 
        limit = 20, 
        offset = 0, 
        category,
        search 
      } = req.query;

      const lives = await this.supabaseService.getActiveLives(
        parseInt(limit), 
        parseInt(offset)
      );

      res.json({
        success: true,
        data: lives,
        pagination: {
          limit: parseInt(limit),
          offset: parseInt(offset),
          total: lives.length,
        },
        message: 'Lives récupérés avec succès',
      });

    } catch (error) {
      console.error('Erreur récupération lives:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Récupérer un live spécifique
   * GET /api/lives/:id
   */
  async getLiveById(req, res) {
    try {
      const { id } = req.params;

      const live = await this.supabaseService.getLiveById(id);

      if (!live) {
        return res.status(404).json({
          success: false,
          error: 'Live non trouvé',
        });
      }

      res.json({
        success: true,
        data: live,
        message: 'Live récupéré avec succès',
      });

    } catch (error) {
      console.error('Erreur récupération live:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Mettre à jour un live
   * PUT /api/lives/:id
   */
  async updateLive(req, res) {
    try {
      const { id } = req.params;
      const updates = req.body;
      const userId = req.user?.id;

      // Vérifier que l'utilisateur est le propriétaire du live
      const live = await this.supabaseService.getLiveById(id);
      
      if (!live) {
        return res.status(404).json({
          success: false,
          error: 'Live non trouvé',
        });
      }

      if (live.host_id !== userId) {
        return res.status(403).json({
          success: false,
          error: 'Non autorisé à modifier ce live',
        });
      }

      const updatedLive = await this.supabaseService.updateLive(id, updates);

      res.json({
        success: true,
        data: updatedLive,
        message: 'Live mis à jour avec succès',
      });

    } catch (error) {
      console.error('Erreur mise à jour live:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Terminer un live
   * POST /api/lives/:id/end
   */
  async endLive(req, res) {
    try {
      const { id } = req.params;
      const userId = req.user?.id;

      // Vérifier que l'utilisateur est le propriétaire du live
      const live = await this.supabaseService.getLiveById(id);
      
      if (!live) {
        return res.status(404).json({
          success: false,
          error: 'Live non trouvé',
        });
      }

      if (live.host_id !== userId) {
        return res.status(403).json({
          success: false,
          error: 'Non autorisé à terminer ce live',
        });
      }

      const endedLive = await this.supabaseService.endLive(id);

      res.json({
        success: true,
        data: endedLive,
        message: 'Live terminé avec succès',
      });

    } catch (error) {
      console.error('Erreur fin live:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Récupérer les messages d'un live
   * GET /api/lives/:id/messages
   */
  async getLiveMessages(req, res) {
    try {
      const { id } = req.params;
      const { limit = 50 } = req.query;

      const messages = await this.supabaseService.getLiveMessages(
        id, 
        parseInt(limit)
      );

      res.json({
        success: true,
        data: messages,
        message: 'Messages récupérés avec succès',
      });

    } catch (error) {
      console.error('Erreur récupération messages:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Envoyer un message dans un live
   * POST /api/lives/:id/messages
   */
  async sendMessage(req, res) {
    try {
      const { id } = req.params;
      const { content, type = 'text' } = req.body;
      const userId = req.user?.id;

      if (!content || !userId) {
        return res.status(400).json({
          success: false,
          error: 'Contenu du message et authentification requis',
        });
      }

      // Récupérer le profil utilisateur pour le nom
      const userProfile = await this.supabaseService.getUserProfile(userId);
      
      const messageData = {
        id: require('uuid').v4(),
        live_id: id,
        user_id: userId,
        username: userProfile?.username || userProfile?.full_name || 'Utilisateur',
        user_avatar: userProfile?.avatar,
        message: content,
        type,
        created_at: new Date().toISOString(),
      };

      const message = await this.supabaseService.sendMessage(messageData);

      res.status(201).json({
        success: true,
        data: message,
        message: 'Message envoyé avec succès',
      });

    } catch (error) {
      console.error('Erreur envoi message:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Statistiques d'un live
   * GET /api/lives/:id/stats
   */
  async getLiveStats(req, res) {
    try {
      const { id } = req.params;

      const live = await this.supabaseService.getLiveById(id);
      
      if (!live) {
        return res.status(404).json({
          success: false,
          error: 'Live non trouvé',
        });
      }

      const messages = await this.supabaseService.getLiveMessages(id, 1000);
      
      const stats = {
        viewerCount: live.viewer_count || 0,
        likeCount: live.like_count || 0,
        giftCount: live.gift_count || 0,
        messageCount: messages.length,
        duration: live.started_at ? 
          Math.floor((new Date() - new Date(live.started_at)) / 1000) : 0,
        isLive: live.is_live,
      };

      res.json({
        success: true,
        data: stats,
        message: 'Statistiques récupérées avec succès',
      });

    } catch (error) {
      console.error('Erreur récupération stats:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }
}

module.exports = LiveController;
