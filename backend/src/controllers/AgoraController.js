const AgoraTokenService = require('../services/agoraTokenService');
const { validationResult } = require('express-validator');

class AgoraController {
  constructor() {
    this.agoraService = new AgoraTokenService();
    this.getConfigInfo = this.getConfigInfo.bind(this);
    this.generateViewerToken = this.generateViewerToken.bind(this);
    this.generateHostToken = this.generateHostToken.bind(this);
    this.generateLiveToken = this.generateLiveToken.bind(this);
    this.createLive = this.createLive.bind(this);
    this.joinLive = this.joinLive.bind(this);
    this.leaveLive = this.leaveLive.bind(this);
    this.refreshToken = this.refreshToken.bind(this);
    this.testConfiguration = this.testConfiguration.bind(this);
  }

  /**
   * Générer un token pour rejoindre un canal en tant que spectateur
   * POST /api/agora/token/viewer
   */
  async generateViewerToken(req, res) {
    try {
      const { channelName, userId } = req.body;

      if (!channelName) {
        return res.status(400).json({
          success: false,
          error: 'Nom de canal requis',
        });
      }

      // Générer un UID unique basé sur l'userId ou aléatoire
      const uid = userId ? this.generateUidFromString(userId) : 0;

      const tokenData = this.agoraService.generateViewerToken(channelName, uid);

      res.json({
        success: true,
        data: tokenData,
        message: 'Token spectateur généré avec succès',
      });

    } catch (error) {
      console.error('Erreur génération token spectateur:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Générer un token pour démarrer un live en tant qu'hôte
   * POST /api/agora/token/host
   */
  async generateHostToken(req, res) {
    try {
      const { channelName, userId } = req.body;

      if (!channelName || !userId) {
        return res.status(400).json({
          success: false,
          error: 'Nom de canal et ID utilisateur requis',
        });
      }

      const uid = this.generateUidFromString(userId);
      const tokenData = this.agoraService.generateHostToken(channelName, uid);

      res.json({
        success: true,
        data: tokenData,
        message: 'Token hôte généré avec succès',
      });

    } catch (error) {
      console.error('Erreur génération token hôte:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Générer un token pour un live stream (générique)
   * POST /api/agora/live-token
   */
  async generateLiveToken(req, res) {
    try {
      const { liveId, userId, role = 'viewer' } = req.body;

      if (!liveId || !userId) {
        return res.status(400).json({
          success: false,
          error: 'Live ID et User ID requis',
        });
      }

      // Générer un nom de canal basé sur le liveId
      const channelName = `live_${liveId}`;
      const uid = this.generateUidFromString(userId);

      let tokenData;
      if (role === 'host' || role === 'publisher') {
        tokenData = this.agoraService.generateHostToken(channelName, uid);
      } else {
        tokenData = this.agoraService.generateViewerToken(channelName, uid);
      }

      res.json({
        success: true,
        data: tokenData,
        message: `Token ${role} généré avec succès pour live ${liveId}`,
      });

    } catch (error) {
      console.error('Erreur génération token live:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Créer un nouveau live avec token Agora
   * POST /api/agora/live/create
   */
  async createLive(req, res) {
    try {
      const {
        title,
        description,
        category,
        tags,
        isPrivate = false,
        maxViewers = 1000,
      } = req.body;

      const userId = req.user?.id; // Depuis le middleware d'auth

      if (!title || !userId) {
        return res.status(400).json({
          success: false,
          error: 'Titre et authentification requis',
        });
      }

      // Générer un ID unique pour le live
      const liveId = uuidv4();
      const channelName = `live_${liveId}`;

      // Générer le token Agora pour l'hôte
      const uid = this.generateUidFromString(userId);
      const agoraTokenData = this.agoraService.generateHostToken(channelName, uid);

      // Créer le live dans Supabase
      const liveData = {
        id: liveId,
        title,
        description,
        category: category || 'Général',
        tags: tags || [],
        host_id: userId,
        is_private: isPrivate,
        max_viewers: maxViewers,
        is_live: true,
        viewer_count: 0,
        like_count: 0,
        gift_count: 0,
        started_at: new Date().toISOString(),
        agora_channel_id: channelName,
        agora_token: agoraTokenData.token,
      };

      const createdLive = await this.supabaseService.createLiveStream(liveData);

      res.status(201).json({
        success: true,
        data: {
          live: createdLive,
          agoraToken: agoraTokenData,
        },
        message: 'Live créé avec succès',
      });

    } catch (error) {
      console.error('Erreur création live:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Rejoindre un live (obtenir token + incrémenter viewers)
   * POST /api/agora/live/:liveId/join
   */
  async joinLive(req, res) {
    try {
      const { liveId } = req.params;
      const userId = req.user?.id || 'anonymous';

      // Récupérer les infos du live
      const live = await this.supabaseService.getLiveById(liveId);
      
      if (!live || !live.is_live) {
        return res.status(404).json({
          success: false,
          error: 'Live non trouvé ou terminé',
        });
      }

      // Générer le token pour le spectateur
      const uid = userId !== 'anonymous' ? this.generateUidFromString(userId) : 0;
      const tokenData = this.agoraService.generateViewerToken(live.agora_channel_id, uid);

      // Incrémenter le nombre de viewers
      if (userId !== 'anonymous') {
        await this.supabaseService.incrementViewerCount(liveId);
      }

      res.json({
        success: true,
        data: {
          live,
          agoraToken: tokenData,
        },
        message: 'Token pour rejoindre le live généré',
      });

    } catch (error) {
      console.error('Erreur rejoindre live:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Quitter un live (décrémenter viewers)
   * POST /api/agora/live/:liveId/leave
   */
  async leaveLive(req, res) {
    try {
      const { liveId } = req.params;
      const userId = req.user?.id;

      if (userId) {
        await this.supabaseService.decrementViewerCount(liveId);
      }

      res.json({
        success: true,
        message: 'Live quitté avec succès',
      });

    } catch (error) {
      console.error('Erreur quitter live:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Renouveler un token expiré
   * POST /api/agora/token/refresh
   */
  async refreshToken(req, res) {
    try {
      const { channelName, userId, role = 'subscriber' } = req.body;

      if (!channelName) {
        return res.status(400).json({
          success: false,
          error: 'Nom de canal requis',
        });
      }

      const uid = userId ? this.generateUidFromString(userId) : 0;
      const tokenData = this.agoraService.generateRtcToken(channelName, uid, role);

      res.json({
        success: true,
        data: tokenData,
        message: 'Token renouvelé avec succès',
      });

    } catch (error) {
      console.error('Erreur renouvellement token:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur interne du serveur',
        details: error.message,
      });
    }
  }

  /**
   * Test de la configuration Agora
   * GET /api/agora/test
   */
  async testConfiguration(req, res) {
    try {
      const testResult = this.agoraService.testConfiguration();
      
      res.json({
        success: testResult.success,
        data: testResult,
        message: testResult.success ? 'Configuration Agora OK' : 'Problème de configuration',
      });

    } catch (error) {
      console.error('Erreur test Agora:', error);
      res.status(500).json({
        success: false,
        error: 'Erreur test configuration',
        details: error.message,
      });
    }
  }

  /**
   * Récupérer les informations de configuration Agora
   * GET /api/agora/config
   */
  getConfigInfo(req, res) {
    try {
      // Ne jamais renvoyer le certificat dans la réponse !
      res.json({
        success: true,
        data: {
          appId: process.env.AGORA_APP_ID || 'non défini',
          certificateConfigured: !!process.env.AGORA_APP_CERTIFICATE,
          isConfigValid: !!process.env.AGORA_APP_ID && !!process.env.AGORA_APP_CERTIFICATE,
          environment: process.env.NODE_ENV || 'development'
        },
        message: 'Configuration Agora récupérée'
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Erreur lors de la récupération de la configuration Agora',
        error: error.message
      });
    }
  }

  /**
   * Génère un UID numérique à partir d'une chaîne
   */
  generateUidFromString(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convertir en 32bit integer
    }
    return Math.abs(hash) % 2147483647; // S'assurer que c'est positif et dans la limite d'Agora
  }
}

module.exports = AgoraController;
