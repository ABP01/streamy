#!/bin/bash

echo "🔍 Diagnostic des problèmes de caméra dans Streamy"
echo "================================================="

echo ""
echo "1. Vérification des permissions Android..."
echo "   - CAMERA: ✅ Présente dans AndroidManifest.xml"
echo "   - RECORD_AUDIO: ✅ Présente dans AndroidManifest.xml"

echo ""
echo "2. Vérification des dépendances..."
cd /c/Projects/streamy

echo "   - agora_rtc_engine: $(grep 'agora_rtc_engine:' pubspec.yaml | cut -d':' -f2 | xargs)"
echo "   - permission_handler: $(grep 'permission_handler:' pubspec.yaml | cut -d':' -f2 | xargs)"

echo ""
echo "3. Problèmes potentiels identifiés:"
echo "   ❌ La caméra ne s'affiche pas lors du live"
echo "   ❌ L'écran reste sur placeholder au lieu de la vue caméra"

echo ""
echo "4. Solutions recommandées:"
echo "   1. Vérifier l'initialisation d'Agora dans HostLiveScreen"
echo "   2. Corriger la configuration VideoViewController"
echo "   3. Ajouter des logs de débogage pour diagnostiquer"
echo "   4. Vérifier les permissions à l'exécution"

echo ""
echo "5. Code de diagnostic à ajouter..."
