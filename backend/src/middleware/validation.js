const { body, param, query, validationResult } = require('express-validator');

/**
 * Middleware pour gérer les erreurs de validation
 */
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Données invalides',
      details: errors.array(),
    });
  }
  
  next();
};

/**
 * Validations pour l'authentification
 */
const validateLogin = [
  body('email')
    .isEmail()
    .withMessage('Email invalide')
    .normalizeEmail(),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Le mot de passe doit contenir au moins 6 caractères'),
  handleValidationErrors,
];

const validateRegister = [
  body('email')
    .isEmail()
    .withMessage('Email invalide')
    .normalizeEmail(),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Le mot de passe doit contenir au moins 6 caractères'),
  body('username')
    .isLength({ min: 3, max: 20 })
    .withMessage('Le nom d\'utilisateur doit contenir entre 3 et 20 caractères')
    .matches(/^[a-zA-Z0-9_]+$/)
    .withMessage('Le nom d\'utilisateur ne peut contenir que des lettres, chiffres et underscores'),
  handleValidationErrors,
];

/**
 * Validations pour les tokens Agora
 */
const validateTokenRequest = [
  body('channelName')
    .isLength({ min: 1, max: 64 })
    .withMessage('Nom de canal requis (1-64 caractères)')
    .matches(/^[a-zA-Z0-9_-]+$/)
    .withMessage('Le nom de canal ne peut contenir que des lettres, chiffres, tirets et underscores'),
  body('userId')
    .optional()
    .isString()
    .withMessage('ID utilisateur doit être une chaîne'),
  handleValidationErrors,
];

/**
 * Validations pour créer un live
 */
const validateCreateLive = [
  body('title')
    .isLength({ min: 1, max: 100 })
    .withMessage('Titre requis (1-100 caractères)'),
  body('description')
    .optional()
    .isLength({ max: 500 })
    .withMessage('Description trop longue (max 500 caractères)'),
  body('category')
    .optional()
    .isString()
    .withMessage('Catégorie doit être une chaîne'),
  body('tags')
    .optional()
    .isArray()
    .withMessage('Tags doit être un tableau'),
  body('isPrivate')
    .optional()
    .isBoolean()
    .withMessage('isPrivate doit être un booléen'),
  body('maxViewers')
    .optional()
    .isInt({ min: 1, max: 10000 })
    .withMessage('maxViewers doit être entre 1 et 10000'),
  handleValidationErrors,
];

/**
 * Validations pour les messages
 */
const validateMessage = [
  body('content')
    .isLength({ min: 1, max: 200 })
    .withMessage('Message requis (1-200 caractères)'),
  body('type')
    .optional()
    .isIn(['text', 'gift', 'like', 'join', 'leave', 'system'])
    .withMessage('Type de message invalide'),
  handleValidationErrors,
];

/**
 * Validations pour les paramètres d'URL
 */
const validateLiveId = [
  param('id')
    .isUUID()
    .withMessage('ID de live invalide'),
  handleValidationErrors,
];

const validateUserId = [
  param('userId')
    .isUUID()
    .withMessage('ID utilisateur invalide'),
  handleValidationErrors,
];

/**
 * Validations pour les query parameters
 */
const validatePagination = [
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limite doit être entre 1 et 100'),
  query('offset')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Offset doit être >= 0'),
  handleValidationErrors,
];

module.exports = {
  handleValidationErrors,
  validateLogin,
  validateRegister,
  validateTokenRequest,
  validateCreateLive,
  validateMessage,
  validateLiveId,
  validateUserId,
  validatePagination,
};
