const express = require('express');
const morgan = require('morgan');

const healthRoutes = require('./routes/health');
const resourceRoutes = require('./routes/resources');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_ENV = process.env.APP_ENV || 'development';

// Middleware
app.use(express.json());
app.use(morgan('combined'));

// Attach environment info to every request
app.use((req, res, next) => {
  req.appEnv = APP_ENV;
  next();
});

// Routes
app.use('/', healthRoutes);
app.use('/api/resources', resourceRoutes);

// Root
app.get('/', (req, res) => {
  res.json({
    name: 'iaclab-api',
    version: '1.0.0',
    environment: req.appEnv,
    message: 'Azure Infrastructure Lab API is running.'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`[${APP_ENV}] iaclab-api listening on port ${PORT}`);
});

module.exports = app;
