# Streamy Backend - Déploiement sur Render

## 🎉 **DÉPLOYÉ AVEC SUCCÈS !**

✅ **URL de production :** https://streamy-backend-xyg8.onrender.com

## 🚀 Déploiement automatique

Ce backend est configuré pour être déployé automatiquement sur Render.

### Configuration requise

1. **Variables d'environnement à configurer sur Render :**
   ```
   NODE_ENV=production
   AGORA_APP_ID=your_agora_app_id
   AGORA_APP_CERTIFICATE=your_agora_certificate
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   JWT_SECRET=your_jwt_secret_production
   JWT_EXPIRES_IN=7d
   JWT_REFRESH_EXPIRES_IN=30d
   CORS_ORIGIN=your_frontend_domain
   ```

2. **Service Health Check :**
   - URL: `/health`
   - Le service répond avec un JSON contenant le statut

### Commandes de déploiement

- **Build :** `npm install`
- **Start :** `npm start`
- **Port :** Défini automatiquement par Render via la variable PORT

### Structure du projet

```
backend/
├── src/
│   ├── server.js          # Point d'entrée principal
│   ├── config/            # Configuration
│   ├── controllers/       # Contrôleurs
│   ├── middleware/        # Middlewares
│   ├── routes/           # Routes API
│   └── services/         # Services métier
├── package.json
└── render.yaml           # Configuration Render
```

### API Endpoints

- `GET /health` - Health check
- `POST /api/agora/token` - Génération de tokens Agora
- Plus d'endpoints dans `/routes/`

### Monitoring

Le service expose une route `/health` qui retourne :
```json
{
  "success": true,
  "data": {
    "service": "Streamy Backend API",
    "status": "healthy",
    "timestamp": "2025-01-17T...",
    "version": "1.0.0",
    "environment": "production"
  }
}
```
