const jwt = require('jsonwebtoken');
const config = require('../config');
const SupabaseService = require('../services/SupabaseService');

/**
 * Middleware d'authentification JWT
 */
const authMiddleware = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'Token d\'authentification requis',
      });
    }

    // Vérifier le token JWT
    const decoded = jwt.verify(token, config.jwt.secret);
    
    // Récupérer les infos utilisateur depuis Supabase
    const supabaseService = new SupabaseService();
    const user = await supabaseService.getUserProfile(decoded.userId);

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('Erreur authentification:', error);
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error: 'Token invalide',
      });
    }
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Token expiré',
      });
    }

    return res.status(500).json({
      success: false,
      error: 'Erreur interne d\'authentification',
    });
  }
};

/**
 * Middleware d'authentification optionnelle
 * L'utilisateur peut être anonyme
 */
const optionalAuthMiddleware = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      req.user = null;
      return next();
    }

    const decoded = jwt.verify(token, config.jwt.secret);
    const supabaseService = new SupabaseService();
    const user = await supabaseService.getUserProfile(decoded.userId);

    req.user = user;
    next();
  } catch (error) {
    // En cas d'erreur, continuer avec user = null
    req.user = null;
    next();
  }
};

/**
 * Générer un token JWT pour un utilisateur
 */
const generateToken = (userId) => {
  return jwt.sign(
    { userId },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn }
  );
};

/**
 * Générer un refresh token
 */
const generateRefreshToken = (userId) => {
  return jwt.sign(
    { userId, type: 'refresh' },
    config.jwt.secret,
    { expiresIn: config.jwt.refreshExpiresIn }
  );
};

/**
 * Vérifier un refresh token
 */
const verifyRefreshToken = (token) => {
  try {
    const decoded = jwt.verify(token, config.jwt.secret);
    if (decoded.type !== 'refresh') {
      throw new Error('Token type invalide');
    }
    return decoded;
  } catch (error) {
    throw new Error('Refresh token invalide');
  }
};

module.exports = {
  authMiddleware,
  optionalAuthMiddleware,
  generateToken,
  generateRefreshToken,
  verifyRefreshToken,
};
