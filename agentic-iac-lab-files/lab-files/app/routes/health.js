const express = require('express');
const router = express.Router();

// Tracks the time the app started
const startTime = Date.now();

// Liveness probe — used by Kubernetes to know if the container is alive.
// Returns 200 as long as the process is running.
router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    uptime_seconds: Math.floor((Date.now() - startTime) / 1000),
    environment: req.appEnv,
    timestamp: new Date().toISOString()
  });
});

// Readiness probe — used by Kubernetes to know if the container is ready to serve traffic.
// In a real app this would check DB connections, caches, downstream services, etc.
router.get('/ready', (req, res) => {
  const ready = isReady();

  if (ready) {
    res.status(200).json({
      status: 'ready',
      checks: {
        app: 'ok',
        config: 'ok'
      },
      timestamp: new Date().toISOString()
    });
  } else {
    res.status(503).json({
      status: 'not_ready',
      checks: {
        app: 'ok',
        config: 'error'
      },
      timestamp: new Date().toISOString()
    });
  }
});

function isReady() {
  // Simulate a readiness check — extend this to check DB, cache, etc.
  return !!process.env.APP_ENV;
}

module.exports = router;
