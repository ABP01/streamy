@echo off
title TEST BACKEND RENDER - STREAMY
color 0E

echo.
echo ========================================
echo 🌐 TEST BACKEND RENDER STREAMY  
echo ========================================
echo.

echo 📡 URL Backend: https://streamy-backend-xyg8.onrender.com
echo.

echo 📍 Test 1: Health Check global...
curl -X GET "https://streamy-backend-xyg8.onrender.com/health" -H "Content-Type: application/json" -w "\nStatus: %%{http_code}\nTime: %%{time_total}s\n" -s
echo.

echo 📍 Test 2: Health Check API Agora...
curl -X GET "https://streamy-backend-xyg8.onrender.com/api/agora/health" -H "Content-Type: application/json" -w "\nStatus: %%{http_code}\nTime: %%{time_total}s\n" -s
echo.

echo 📍 Test 3: Configuration Agora...
curl -X GET "https://streamy-backend-xyg8.onrender.com/api/agora/config" -H "Content-Type: application/json" -w "\nStatus: %%{http_code}\nTime: %%{time_total}s\n" -s
echo.

echo 📍 Test 4: Test tokens Agora...
curl -X GET "https://streamy-backend-xyg8.onrender.com/api/agora/test-tokens" -H "Content-Type: application/json" -w "\nStatus: %%{http_code}\nTime: %%{time_total}s\n" -s
echo.

echo 💡 DIAGNOSTIC:
echo    ✅ Status 200 = Backend opérationnel
echo    ❌ Status 404/500 = Problème backend  
echo    ⏳ Time ^> 5s = Service endormi (Render)
echo.

echo 🔧 SOLUTIONS si problème:
echo    1. Vérifier le déploiement sur Render
echo    2. Vérifier les variables d'environnement
echo    3. Vérifier les logs Render
echo    4. Redémarrer le service Render
echo.

pause
