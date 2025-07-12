const express = require('express');
const { body } = require('express-validator');
const AgoraController = require('../controllers/agoraController');

const router = express.Router();
const agoraController = new AgoraController();

// Validation middleware
const validateTokenRequest = [
  body('channelName')
    .isString()
    .isLength({ min: 1, max: 64 })
    .matches(/^[a-zA-Z0-9_-]+$/)
    .withMessage('Le nom du canal doit contenir uniquement des caractères alphanumériques, tirets et underscores'),
  body('userId')
    .isString()
    .isLength({ min: 1, max: 255 })
    .withMessage('ID utilisateur requis')
];

const validateLiveTokenRequest = [
  body('liveId')
    .isUUID()
    .withMessage('ID de live doit être un UUID valide'),
  body('userId')
    .isString()
    .isLength({ min: 1, max: 255 })
    .withMessage('ID utilisateur requis'),
  body('role')
    .isIn(['host', 'viewer'])
    .withMessage('Le rôle doit être host ou viewer')
];

/**
 * @route GET /api/agora/test-config
 * @desc Tester la configuration Agora
 * @access Public
 */
router.get('/test-config', (req, res) => agoraController.testConfiguration(req, res));

/**
 * @route GET /api/agora/config
 * @desc Obtenir les informations de configuration
 * @access Public
 */
router.get('/config', (req, res) => agoraController.getConfigInfo(req, res));

/**
 * @route POST /api/agora/viewer-token
 * @desc Générer un token pour spectateur
 * @access Public
 */
router.post('/viewer-token',
  validateTokenRequest,
  (req, res) => agoraController.generateViewerToken(req, res)
);

/**
 * @route POST /api/agora/host-token
 * @desc Générer un token pour hôte
 * @access Public
 */
router.post('/host-token',
  validateTokenRequest,
  (req, res) => agoraController.generateHostToken(req, res)
);

/**
 * @route POST /api/agora/live-token
 * @desc Générer un token pour un live stream
 * @access Public
 */
router.post('/live-token',
  validateLiveTokenRequest,
  (req, res) => agoraController.generateLiveToken(req, res)
);

/**
 * @route GET /api/agora/test-tokens
 * @desc Générer des tokens de test (développement uniquement)
 * @access Public
 */
router.get('/test-tokens', (req, res) => agoraController.generateTestTokens(req, res));

/**
 * @route GET /api/agora/health
 * @desc Check de santé du service Agora
 * @access Public
 */
router.get('/health', (req, res) => {
  try {
    const agoraService = new (require('../services/agoraTokenService'))();
    const isValid = agoraService.validateConfiguration();
    
    res.json({
      success: true,
      data: {
        service: 'Agora Token Service',
        status: isValid ? 'healthy' : 'unhealthy',
        timestamp: new Date().toISOString(),
        configuration: isValid ? 'valid' : 'invalid'
      },
      message: isValid ? 'Service Agora opérationnel' : 'Service Agora défaillant'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      data: {
        service: 'Agora Token Service',
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: error.message
      },
      message: 'Erreur du service Agora'
    });
  }
});

module.exports = router;
