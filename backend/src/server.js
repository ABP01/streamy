require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');

// Routes
const agoraRoutes = require('./routes/agora');

// Initialisation d'Express
const app = express();

// Configuration du port
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Middleware de sécurité
app.use(helmet({
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: false
}));

// CORS
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: process.env.CORS_CREDENTIALS === 'true' || false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key']
}));

// Middleware général
app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Route de santé
app.get('/health', (req, res) => {
  res.json({
    success: true,
    data: {
      service: 'Streamy Backend API',
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development'
    },
    message: 'API opérationnelle'
  });
});

// Route d'information
app.get('/', (req, res) => {
  res.json({
    name: 'Streamy Backend API',
    version: '1.0.0',
    description: 'API backend pour l\'application Streamy',
    endpoints: {
      health: '/health',
      agora: '/api/agora/*'
    },
    documentation: 'Voir les routes dans /routes pour plus de détails'
  });
});

// Routes API
app.use('/api/agora', agoraRoutes);

// Middleware de gestion d'erreurs
app.use((err, req, res, next) => {
  console.error('❌ Erreur serveur:', err);
  
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Erreur interne du serveur',
    error: process.env.NODE_ENV === 'development' ? err.stack : undefined,
    timestamp: new Date().toISOString()
  });
});

// Middleware pour les routes non trouvées
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.originalUrl} non trouvée`,
    availableRoutes: [
      'GET /',
      'GET /health',
      'GET /api/agora/config',
      'GET /api/agora/test-config',
      'POST /api/agora/viewer-token',
      'POST /api/agora/host-token',
      'POST /api/agora/live-token'
    ]
  });
});

// Test de la configuration Agora au démarrage
async function testAgoraConfiguration() {
  try {
    const AgoraTokenService = require('./services/agoraTokenService');
    const agoraService = new AgoraTokenService();
    
    const isValid = agoraService.validateConfiguration();
    
    if (isValid) {
      console.log('✅ Configuration Agora validée avec succès');
      
      // Générer un token de test
      const testToken = agoraService.generateTestTokens();
      console.log('🧪 Token de test généré pour canal:', testToken.testChannel);
    } else {
      console.warn('⚠️  Configuration Agora invalide - vérifiez vos variables d\'environnement');
    }
  } catch (error) {
    console.error('❌ Erreur lors du test de la configuration Agora:', error.message);
  }
}

// Démarrage du serveur
app.listen(PORT, HOST, async () => {
  console.log('\n🚀 ===== STREAMY BACKEND API =====');
  console.log(`📡 Serveur démarré sur http://${process.env.HOST || '0.0.0.0'}:${PORT}`);
  console.log(`🌍 Environnement: ${process.env.NODE_ENV || 'development'}`);
  console.log(`⏰ Démarré le: ${new Date().toLocaleString()}`);
  console.log('================================\n');

  // Tester la configuration Agora
  await testAgoraConfiguration();

  console.log('\n📚 Routes disponibles:');
  console.log('- GET  /health              - Status de l\'API');
  console.log('- GET  /api/agora/config    - Configuration Agora');
  console.log('- POST /api/agora/live-token - Token pour live stream');
  console.log('- GET  /api/agora/test-tokens - Tokens de test');
  console.log('\n✨ Backend prêt à recevoir des requêtes!\n');
});

// Gestion des signaux de fermeture
process.on('SIGTERM', () => {
  console.log('\n🛑 Signal SIGTERM reçu, arrêt du serveur...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('\n🛑 Signal SIGINT reçu, arrêt du serveur...');
  process.exit(0);
});

module.exports = app;
