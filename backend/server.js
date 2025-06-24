const express = require('express');
const { createClient } = require('@supabase/supabase-js');
const Agora = require('agora-access-token');
require('dotenv').config(); // Charge les variables d'environnement depuis un .env si présent

const app = express();
app.use(express.json());

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const AGORA_APP_ID = process.env.AGORA_APP_ID;
const AGORA_CERTIFICATE = process.env.AGORA_CERTIFICATE;

if (!SUPABASE_URL || !SUPABASE_KEY || !AGORA_APP_ID || !AGORA_CERTIFICATE) {
  console.error('Veuillez définir toutes les variables d\'environnement nécessaires.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Middleware d'authentification
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const token = authHeader.split(' ')[1];
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    req.user = user;
    next();
  } catch (err) {
    return res.status(500).json({ error: 'Authentication failed' });
  }
};

// Générer un token Agora
app.post('/api/agora-token', authenticate, (req, res) => {
  try {
    const { channelName, isBroadcaster } = req.body;
    if (!channelName) {
      return res.status(400).json({ error: 'channelName requis' });
    }
    const uid = Math.floor(Math.random() * 100000) + 1;
    const role = isBroadcaster ? Agora.RtcRole.PUBLISHER : Agora.RtcRole.SUBSCRIBER;
    const expirationTime = 3600; // 1 heure
    const currentTime = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTime + expirationTime;
    const token = Agora.RtcTokenBuilder.buildTokenWithUid(
      AGORA_APP_ID,
      AGORA_CERTIFICATE,
      channelName,
      uid,
      role,
      privilegeExpiredTs
    );
    return res.json({ token, uid });
  } catch (err) {
    return res.status(500).json({ error: 'Erreur lors de la génération du token' });
  }
});

// Route de test (optionnelle)
app.get('/', (req, res) => {
  res.send('API Streamy backend opérationnelle');
});

// Démarrer le serveur
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));