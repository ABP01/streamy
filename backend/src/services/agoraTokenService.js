const { RtcTokenBuilder, RtcRole } = require('agora-token');

/**
 * Service pour gérer les tokens Agora RTC
 */
class AgoraTokenService {
  constructor() {
    this.appId = process.env.AGORA_APP_ID;
    this.appCertificate = process.env.AGORA_APP_CERTIFICATE;
    
    if (!this.appId || !this.appCertificate) {
      throw new Error('Configuration Agora manquante: AGORA_APP_ID et AGORA_APP_CERTIFICATE sont requis');
    }
    
    // Durée de validité par défaut : 24 heures
    this.defaultExpireTime = 24 * 3600; // en secondes
    
    console.log('🚀 Service Agora Token initialisé');
    console.log(`App ID: ${this.appId.substring(0, 8)}...`);
    console.log(`Certificate configuré: ${this.appCertificate ? 'Oui' : 'Non'}`);
  }

  /**
   * Génère un token RTC pour rejoindre un canal
   * @param {string} channelName - Nom du canal
   * @param {number} uid - ID utilisateur (0 pour auto-assigné)
   * @param {string} role - 'publisher' pour hôte, 'audience' pour spectateur
   * @param {number} expireTime - Durée de validité en secondes (optionnel)
   * @returns {object} Token et informations associées
   */
  generateRtcToken(channelName, uid = 0, role = 'audience', expireTime = null) {
    try {
      // Validation des paramètres
      if (!channelName || typeof channelName !== 'string') {
        throw new Error('Le nom du canal est requis et doit être une chaîne');
      }

      if (typeof uid !== 'number' || uid < 0) {
        throw new Error('UID doit être un nombre positif ou 0');
      }

      // Déterminer le rôle Agora
      const agoraRole = role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
      
      // Calculer le timestamp d'expiration
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const tokenExpireTime = expireTime || (currentTimestamp + this.defaultExpireTime);

      // Générer le token
      const token = RtcTokenBuilder.buildTokenWithUid(
        this.appId,
        this.appCertificate,
        channelName,
        uid,
        agoraRole,
        tokenExpireTime
      );

      const result = {
        token,
        appId: this.appId,
        channelName,
        uid,
        role,
        expireTime: tokenExpireTime,
        expiresAt: new Date(tokenExpireTime * 1000).toISOString(),
        generatedAt: new Date().toISOString()
      };

      console.log(`✅ Token généré pour canal: ${channelName}, role: ${role}, uid: ${uid}`);
      return result;

    } catch (error) {
      console.error('❌ Erreur génération token:', error.message);
      throw new Error(`Impossible de générer le token: ${error.message}`);
    }
  }

  /**
   * Génère un token pour un spectateur
   * @param {string} channelName - Nom du canal
   * @param {string} userId - ID de l'utilisateur
   * @returns {object} Token pour spectateur
   */
  generateViewerToken(channelName, userId) {
    const uid = this.generateUidFromUserId(userId);
    return this.generateRtcToken(channelName, uid, 'audience');
  }

  /**
   * Génère un token pour un hôte
   * @param {string} channelName - Nom du canal
   * @param {string} userId - ID de l'utilisateur hôte
   * @returns {object} Token pour hôte
   */
  generateHostToken(channelName, userId) {
    const uid = this.generateUidFromUserId(userId);
    return this.generateRtcToken(channelName, uid, 'publisher');
  }

  /**
   * Renouvelle un token existant
   * @param {string} channelName - Nom du canal
   * @param {number} uid - UID de l'utilisateur
   * @param {string} role - Rôle de l'utilisateur
   * @returns {object} Nouveau token
   */
  renewToken(channelName, uid, role) {
    console.log(`🔄 Renouvellement token pour canal: ${channelName}, uid: ${uid}`);
    return this.generateRtcToken(channelName, uid, role);
  }

  /**
   * Vérifie si un token est encore valide
   * @param {number} expireTime - Timestamp d'expiration
   * @returns {boolean} True si valide
   */
  isTokenValid(expireTime) {
    const currentTimestamp = Math.floor(Date.now() / 1000);
    return expireTime > currentTimestamp;
  }

  /**
   * Génère un UID numérique à partir d'un ID utilisateur string
   * @param {string} userId - ID utilisateur
   * @returns {number} UID numérique
   */
  generateUidFromUserId(userId) {
    if (!userId) return 0;
    
    // Créer un hash simple mais déterministe
    let hash = 0;
    for (let i = 0; i < userId.length; i++) {
      const char = userId.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convertir en 32bit integer
    }
    
    // S'assurer que le résultat est positif et dans la plage acceptable
    return Math.abs(hash) % 2147483647; // Max int32
  }

  /**
   * Génère des tokens de test pour le développement
   * @returns {object} Tokens de test
   */
  generateTestTokens() {
    const testChannel = 'test-channel';
    const hostToken = this.generateHostToken(testChannel, 'test-host');
    const viewerToken = this.generateViewerToken(testChannel, 'test-viewer');

    return {
      testChannel,
      host: hostToken,
      viewer: viewerToken,
      note: 'Tokens de test valides pour 24h'
    };
  }

  /**
   * Valide la configuration Agora
   * @returns {boolean} True si la configuration est valide
   */
  validateConfiguration() {
    try {
      // Test de génération d'un token simple
      const testToken = this.generateRtcToken('config-test', 1, 'audience');
      return testToken && testToken.token && testToken.token.length > 50;
    } catch (error) {
      console.error('❌ Configuration Agora invalide:', error.message);
      return false;
    }
  }

  /**
   * Obtient les informations de configuration (sans les secrets)
   * @returns {object} Informations de configuration
   */
  getConfigInfo() {
    return {
      appId: this.appId,
      hasAppCertificate: !!this.appCertificate,
      defaultExpireTime: this.defaultExpireTime,
      isConfigValid: this.validateConfiguration()
    };
  }
}

module.exports = AgoraTokenService;
