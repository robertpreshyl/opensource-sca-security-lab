#!/bin/bash

# Master SCA Scanning Script
# Author: Precious Robert
# Date: January 2026

set -e

echo "========================================="
echo "Open-Source SCA Security Testing Lab"
echo "Automated Vulnerability Scanning Pipeline"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create results directories
mkdir -p 01-container-scanning/scan-results
mkdir -p 02-dependency-scanning/scan-reports
mkdir -p 03-sbom-generation/container-sboms
mkdir -p 03-sbom-generation/application-sboms
mkdir -p 05-findings

echo "${GREEN}[1/5] Building Docker images...${NC}"
echo "-----------------------------------"

cd 01-container-scanning/vulnerable-node-app
docker build -t vulnerable-node-app:latest .
cd ../vulnerable-python-app
docker build -t vulnerable-python-app:latest .
cd ../..

echo ""
echo "${GREEN}[2/5] Scanning Docker images with Trivy...${NC}"
echo "-----------------------------------"

echo "Scanning vulnerable-node-app..."
trivy image \
  --severity CRITICAL,HIGH,MEDIUM \
  --format table \
  --output 01-container-scanning/scan-results/node-app-scan.txt \
  vulnerable-node-app:latest

trivy image \
  --severity CRITICAL,HIGH,MEDIUM \
  --format json \
  --output 01-container-scanning/scan-results/node-app-scan.json \
  vulnerable-node-app:latest

echo "Scanning vulnerable-python-app..."
trivy image \
  --severity CRITICAL,HIGH,MEDIUM \
  --format table \
  --output 01-container-scanning/scan-results/python-app-scan.txt \
  vulnerable-python-app:latest

trivy image \
  --severity CRITICAL,HIGH,MEDIUM \
  --format json \
  --output 01-container-scanning/scan-results/python-app-scan.json \
  vulnerable-python-app:latest

echo ""
echo "${GREEN}[3/5] Scanning dependencies (filesystem)...${NC}"
echo "-----------------------------------"

echo "Scanning Node.js dependencies..."
trivy fs \
  --severity CRITICAL,HIGH,MEDIUM \
  --format table \
  --output 02-dependency-scanning/scan-reports/node-dependencies.txt \
  01-container-scanning/vulnerable-node-app/

echo "Scanning Python dependencies..."
trivy fs \
  --severity CRITICAL,HIGH,MEDIUM \
  --format table \
  --output 02-dependency-scanning/scan-reports/python-dependencies.txt \
  01-container-scanning/vulnerable-python-app/

echo ""
echo "${GREEN}[4/5] Generating SBOMs...${NC}"
echo "-----------------------------------"

echo "Generating SBOM for node-app (CycloneDX format)..."
trivy image \
  --format cyclonedx \
  --output 03-sbom-generation/container-sboms/node-app-sbom.json \
  vulnerable-node-app:latest

echo "Generating SBOM for python-app (CycloneDX format)..."
trivy image \
  --format cyclonedx \
  --output 03-sbom-generation/container-sboms/python-app-sbom.json \
  vulnerable-python-app:latest

echo ""
echo "${GREEN}[5/5] Generating summary report...${NC}"
echo "-----------------------------------"

# Extract vulnerability counts
NODE_CRITICAL=$(grep -c "CRITICAL" 01-container-scanning/scan-results/node-app-scan.txt || echo "0")
NODE_HIGH=$(grep -c "HIGH" 01-container-scanning/scan-results/node-app-scan.txt || echo "0")
PYTHON_CRITICAL=$(grep -c "CRITICAL" 01-container-scanning/scan-results/python-app-scan.txt || echo "0")
PYTHON_HIGH=$(grep -c "HIGH" 01-container-scanning/scan-results/python-app-scan.txt || echo "0")

# Generate metrics summary
cat > 05-findings/metrics-summary.md << EOF
# SCA Scanning Metrics Summary

**Scan Date:** $(date)  
**Tools Used:** Trivy v$(trivy --version | head -n 1 | awk '{print $2}')

---

## Scan Statistics

### Docker Images Scanned
- **vulnerable-node-app:latest** (Node.js 14.17.0)
- **vulnerable-python-app:latest** (Python 3.8.10)

### Vulnerability Counts

| Image | CRITICAL | HIGH | MEDIUM | TOTAL |
|-------|----------|------|--------|-------|
| Node.js App | $NODE_CRITICAL | $NODE_HIGH | - | - |
| Python App | $PYTHON_CRITICAL | $PYTHON_HIGH | - | - |

### SBOMs Generated
- ✅ Node.js App SBOM (CycloneDX format)
- ✅ Python App SBOM (CycloneDX format)

---

## Key Findings

### Critical Issues
$(grep "CRITICAL" 01-container-scanning/scan-results/node-app-scan.txt | head -n 5 || echo "See detailed scan reports")

### Recommendations
1. Update Node.js base image to latest LTS version
2. Upgrade vulnerable npm packages
3. Update Python base image to 3.11+
4. Replace outdated Python dependencies
5. Implement automated dependency scanning in CI/CD

---

**Detailed reports available in:**
- \`01-container-scanning/scan-results/\`
- \`02-dependency-scanning/scan-reports/\`
- \`03-sbom-generation/container-sboms/\`

**Next Steps:**
Review \`05-findings/vulnerability-analysis.md\` for detailed findings and remediation guidance.
EOF

echo ""
echo "${GREEN}=========================================${NC}"
echo "${GREEN}✅ Scanning Complete!${NC}"
echo "${GREEN}=========================================${NC}"
echo ""
echo "📊 Results Summary:"
echo "  - Node.js App: $NODE_CRITICAL Critical, $NODE_HIGH High"
echo "  - Python App: $PYTHON_CRITICAL Critical, $PYTHON_HIGH High"
echo ""
echo "📁 Output Locations:"
echo "  - Scan Results: 01-container-scanning/scan-results/"
echo "  - Dependency Reports: 02-dependency-scanning/scan-reports/"
echo "  - SBOMs: 03-sbom-generation/container-sboms/"
echo "  - Metrics: 05-findings/metrics-summary.md"
echo ""
echo "${YELLOW}⚠️  Review findings and create remediation plan${NC}"
echo ""
