@echo off
title SOLUTION STREAMING STREAMY - CORRECTION COMPLETE
color 0E

echo.
echo ========================================
echo 🚀 SOLUTION STREAMING STREAMY
echo ========================================
echo.

echo 📋 DIAGNOSTIC DES PROBLEMES:
echo    ❌ Backend non demarre
echo    ❌ Interface live defaillante  
echo    ❌ Transmission video bloquee
echo.

echo 🔧 CORRECTIONS APPLIQUEES:
echo    ✅ Widget Enhanced Live Player cree
echo    ✅ Gestionnaire connexion Agora ameliore
echo    ✅ Interface moderne implementee
echo    ✅ Script de demarrage backend
echo.

echo 📍 Etape 1: Demarrage du backend...
echo Lancement du serveur Node.js avec les tokens Agora
start "Backend Streamy" "%~dp0start_backend.bat"

echo.
echo ⏳ Attendre 5 secondes pour le demarrage du backend...
timeout /t 5 /nobreak >nul

echo.
echo 📍 Etape 2: Test de connexion backend...
curl -s http://localhost:3000/api/agora/health >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Backend non accessible - Verifiez manuellement
) else (
    echo ✅ Backend operationnel sur http://localhost:3000
)

echo.
echo 📍 Etape 3: Configuration Flutter...
cd /d "%~dp0..\"

echo 🧹 Nettoyage du cache Flutter...
call flutter clean

echo 📦 Installation des dependances...
call flutter pub get

echo.
echo 📍 Etape 4: Modifications de configuration...

echo 📝 Mise a jour app_config.dart...
powershell -Command "(Get-Content lib\config\app_config.dart) -replace 'useAgoraToken = false', 'useAgoraToken = true' | Set-Content lib\config\app_config.dart"

echo.
echo 📍 Etape 5: Remplacement de l'interface live...

echo 🔄 Mise a jour du TikTok Style Live Screen...
powershell -Command "$content = Get-Content lib\screens\tiktok_style_live_screen.dart; $content = $content -replace 'LivePlayerWidget', 'EnhancedLivePlayer'; Set-Content lib\screens\tiktok_style_live_screen.dart $content"

echo.
echo 🚀 SOLUTION COMPLETE!
echo.
echo 📱 PROCHAINES ETAPES:
echo    1. Demarrer l'application: flutter run
echo    2. Creer un nouveau live
echo    3. Tester la transmission video
echo    4. Verifier l'interface moderne
echo.
echo 🔗 URLs utiles:
echo    - Backend: http://localhost:3000
echo    - API Agora: http://localhost:3000/api/agora
echo    - Health Check: http://localhost:3000/api/agora/health
echo.
echo 💡 CONSEILS:
echo    - Utilisez un device physique pour de meilleures performances
echo    - Verifiez les permissions camera/micro
echo    - Consultez les logs Flutter pour debug
echo.

pause
