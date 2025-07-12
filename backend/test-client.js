// Test client pour vérifier que le backend fonctionne
const http = require('http');

function testEndpoint(path, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let responseBody = '';
      
      res.on('data', (chunk) => {
        responseBody += chunk;
      });
      
      res.on('end', () => {
        try {
          const parsed = JSON.parse(responseBody);
          resolve({
            status: res.statusCode,
            data: parsed
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            data: responseBody
          });
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    if (data && method !== 'GET') {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

async function runTests() {
  console.log('🧪 Test du backend Streamy...\n');

  try {
    // Test 1: Health check
    console.log('1. Test du health check...');
    const health = await testEndpoint('/health');
    console.log(`   Status: ${health.status}`);
    console.log(`   Response:`, health.data);
    console.log('');

    // Test 2: Configuration Agora
    console.log('2. Test de la configuration Agora...');
    const config = await testEndpoint('/api/agora/config');
    console.log(`   Status: ${config.status}`);
    console.log(`   Response:`, config.data);
    console.log('');

    // Test 3: Tokens de test
    console.log('3. Test des tokens de test...');
    const testTokens = await testEndpoint('/api/agora/test-tokens');
    console.log(`   Status: ${testTokens.status}`);
    console.log(`   Response:`, testTokens.data);
    console.log('');

    // Test 4: Token pour live
    console.log('4. Test de génération de token pour live...');
    const liveToken = await testEndpoint('/api/agora/live-token', 'POST', {
      liveId: '123e4567-e89b-12d3-a456-426614174000',
      userId: 'test-user-123',
      role: 'viewer'
    });
    console.log(`   Status: ${liveToken.status}`);
    console.log(`   Response:`, liveToken.data);
    console.log('');

    console.log('✅ Tous les tests terminés!');

  } catch (error) {
    console.error('❌ Erreur lors des tests:', error.message);
  }
}

runTests();
