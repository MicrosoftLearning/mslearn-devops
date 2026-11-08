const express = require('express');
const router = express.Router();

// Static in-memory dataset — simulates an Azure resource inventory API.
// In a real app, this would query Azure Resource Manager or a database.
const resources = [
  {
    id: 'res-001',
    name: 'vnet-iaclab',
    type: 'Microsoft.Network/virtualNetworks',
    region: 'eastus',
    environment: 'training',
    tags: { Owner: 'lab-user', CostCenter: 'Lab001' }
  },
  {
    id: 'res-002',
    name: 'vm-iaclab',
    type: 'Microsoft.Compute/virtualMachines',
    region: 'eastus',
    environment: 'training',
    tags: { Owner: 'lab-user', CostCenter: 'Lab001' }
  },
  {
    id: 'res-003',
    name: 'fw-iaclab',
    type: 'Microsoft.Network/azureFirewalls',
    region: 'eastus',
    environment: 'training',
    tags: { Owner: 'lab-user', CostCenter: 'Lab001' }
  },
  {
    id: 'res-004',
    name: 'law-iaclab',
    type: 'Microsoft.OperationalInsights/workspaces',
    region: 'eastus',
    environment: 'training',
    tags: { Owner: 'lab-user', CostCenter: 'Lab001' }
  },
  {
    id: 'res-005',
    name: 'bas-iaclab',
    type: 'Microsoft.Network/bastionHosts',
    region: 'eastus',
    environment: 'training',
    tags: { Owner: 'lab-user', CostCenter: 'Lab001' }
  }
];

// GET /api/resources — list all resources
router.get('/', (req, res) => {
  const { type, region } = req.query;

  let result = resources;

  if (type) {
    result = result.filter(r => r.type.toLowerCase().includes(type.toLowerCase()));
  }

  if (region) {
    result = result.filter(r => r.region.toLowerCase() === region.toLowerCase());
  }

  res.json({
    count: result.length,
    environment: req.appEnv,
    resources: result
  });
});

// GET /api/resources/:id — get a single resource by ID
router.get('/:id', (req, res) => {
  const resource = resources.find(r => r.id === req.params.id);

  if (!resource) {
    return res.status(404).json({ error: `Resource '${req.params.id}' not found` });
  }

  res.json(resource);
});

// GET /api/resources/summary/types — count resources grouped by type
router.get('/summary/types', (req, res) => {
  const summary = resources.reduce((acc, r) => {
    acc[r.type] = (acc[r.type] || 0) + 1;
    return acc;
  }, {});

  res.json({
    environment: req.appEnv,
    total: resources.length,
    by_type: summary
  });
});

module.exports = router;
