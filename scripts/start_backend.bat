@echo off
title Backend Streamy - Serveur Live Streaming
color 0A

echo.
echo ========================================
echo 🚀 BACKEND STREAMY - LIVE STREAMING 
echo ========================================
echo.

echo 📍 Navigation vers le repertoire backend...
cd /d "%~dp0\..\backend"

echo.
echo 🔍 Verification de l'environnement...
if not exist "package.json" (
    echo ❌ Erreur: package.json introuvable
    echo ❌ Assurez-vous d'etre dans le bon repertoire
    pause
    exit /b 1
)

if not exist ".env" (
    echo ⚠️  Attention: Fichier .env manquant
    echo 📋 Creation depuis .env.example...
    copy ".env.example" ".env" >nul
    echo ✅ Fichier .env cree
)

echo.
echo 📦 Installation des dependances...
call npm install
if errorlevel 1 (
    echo ❌ Erreur lors de l'installation des dependances
    pause
    exit /b 1
)

echo.
echo 🔧 Configuration Agora detectee:
echo    - App ID: 28918fa47b4042c28f962d26dc5f27dd
echo    - Certificate: Pret pour tokens sécurisés
echo.

echo 🚀 Demarrage du serveur backend...
echo 📡 Serveur disponible sur: http://localhost:3000
echo 🔗 API Agora: http://localhost:3000/api/agora
echo.
echo ⏸️  Appuyez sur Ctrl+C pour arreter le serveur
echo.

node src/server.js

echo.
echo 🛑 Serveur arrête
pause
