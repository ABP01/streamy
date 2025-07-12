const { RateLimiterMemory } = require('rate-limiter-flexible');
const config = require('../config');

// Rate limiter général
const generalLimiter = new RateLimiterMemory({
  points: config.rateLimit.maxRequests, // Nombre de requêtes
  duration: config.rateLimit.windowMs / 1000, // Fenêtre en secondes
  blockDuration: 60, // Bloquer pendant 60 secondes
});

// Rate limiter pour l'authentification (plus strict)
const authLimiter = new RateLimiterMemory({
  points: 5, // 5 tentatives
  duration: 900, // 15 minutes
  blockDuration: 900, // Bloquer pendant 15 minutes
});

// Rate limiter pour la génération de tokens
const tokenLimiter = new RateLimiterMemory({
  points: 20, // 20 tokens par minute
  duration: 60, // 1 minute
  blockDuration: 300, // Bloquer pendant 5 minutes
});

// Rate limiter pour les messages de chat
const messageLimiter = new RateLimiterMemory({
  points: 10, // 10 messages par minute
  duration: 60, // 1 minute
  blockDuration: 120, // Bloquer pendant 2 minutes
});

/**
 * Middleware de rate limiting général
 */
const rateLimitMiddleware = (limiter, errorMessage = 'Trop de requêtes') => {
  return async (req, res, next) => {
    try {
      const key = req.ip || req.connection.remoteAddress;
      await limiter.consume(key);
      next();
    } catch (rejRes) {
      const secs = Math.round(rejRes.msBeforeNext / 1000) || 1;
      res.set('Retry-After', String(secs));
      
      return res.status(429).json({
        success: false,
        error: errorMessage,
        retryAfter: secs,
      });
    }
  };
};

/**
 * Rate limiting pour les routes générales
 */
const generalRateLimit = rateLimitMiddleware(
  generalLimiter, 
  'Trop de requêtes. Veuillez patienter.'
);

/**
 * Rate limiting pour l'authentification
 */
const authRateLimit = rateLimitMiddleware(
  authLimiter, 
  'Trop de tentatives de connexion. Veuillez patienter 15 minutes.'
);

/**
 * Rate limiting pour la génération de tokens
 */
const tokenRateLimit = rateLimitMiddleware(
  tokenLimiter, 
  'Trop de demandes de tokens. Veuillez patienter.'
);

/**
 * Rate limiting pour les messages
 */
const messageRateLimit = rateLimitMiddleware(
  messageLimiter, 
  'Trop de messages envoyés. Veuillez patienter.'
);

module.exports = {
  generalRateLimit,
  authRateLimit,
  tokenRateLimit,
  messageRateLimit,
};
