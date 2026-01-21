const express = require('express');
const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.send('Vulnerable Node.js App - SCA Testing Lab');
});

app.get('/health', (req, res) => {
  res.json({ 
    status: 'running',
    message: 'This app has intentionally outdated dependencies for SCA scanning demonstration'
  });
});

app.listen(PORT, () => {
  console.log(`Vulnerable app running on port ${PORT}`);
  console.log('WARNING: This app contains known vulnerabilities for testing purposes only');
});
