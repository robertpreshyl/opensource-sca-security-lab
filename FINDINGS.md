# Container Security Analysis - Comprehensive Findings

**Analysis Date:** January 21, 2026  
**Tool:** Trivy v0.68.2  
**Analyst:** ASLabs (AllyShip Security Laboratories)  
**Contact:** support@allyshipglobal.com

---

## Executive Summary

I performed comprehensive vulnerability scanning on both official Docker base images and custom vulnerable applications to understand real-world container security risks.

**Total Vulnerabilities Identified: 1,646 across 4 container images**

### Scan Results Overview

| Image | Total Vulns | CRITICAL | HIGH | Base OS |
|-------|-------------|----------|------|----------|
| **vuln-node-app** | 468 | 80 | 388 | Debian 9.13 EOL |
| **vuln-python-app** | 1,178 | 85 | 1,093 | Debian 10.10 EOL |
| node:14.17.0 | 470 | 30 | 440 | Debian 9 EOL |
| python:3.8.10 | 1,170 | 85 | 1,085 | Debian 10 EOL |

**Key Finding:** Custom applications with vulnerable dependencies show similar vulnerability counts to base images, with 434-1,166 OS-level vulnerabilities plus 12-34 package-specific CVEs.

**Business Impact:** Applications using EOL base images inherit unfixable vulnerabilities. For industrial systems with 5-10 year lifecycles, continuous SCA scanning is essential.

---

## Scan Methodology

### Custom Vulnerable Applications

```bash
# 1. Built intentionally vulnerable Node.js app
cd 01-container-scanning/vulnerable-node-app
docker build -t vuln-node-app .

# Dependencies: express 4.17.1, axios 0.21.1, lodash 4.17.19, moment 2.29.1
# Base: node:14.17.0 (Debian 9.13)

# 2. Built intentionally vulnerable Python app
cd ../vulnerable-python-app
docker build -t vuln-python-app .

# Dependencies: Flask 2.0.1, cryptography 3.3.2, urllib3 1.26.4, setuptools 57.0.0
# Base: python:3.8.10 (Debian 10.10)

# 3. Scanned both custom apps
trivy image --severity CRITICAL,HIGH vuln-node-app \
  | tee scan-results/vuln-node-app-scan.txt

trivy image --severity CRITICAL,HIGH vuln-python-app \
  | tee scan-results/vuln-python-app-scan.txt
```

### Base Image Analysis

```bash
# 4. Compared with official base images
trivy image --severity CRITICAL,HIGH node:14.17.0
trivy image --severity CRITICAL,HIGH python:3.8.10

# 5. Generated detailed JSON for deep analysis
trivy image --severity CRITICAL,HIGH \
  --format json \
  --output scan-results/node-14-detailed.json \
  node:14.17.0

# 6. Parsed JSON to find patterns
jq '.Results[].Vulnerabilities[] | 
    select(.Severity=="CRITICAL") | 
    "\(.VulnerabilityID)|\(.PkgName)|\(.Title)"' \
   scan-results/node-14-detailed.json
```

---

## Vulnerability Breakdown

### Custom Application Findings

#### vuln-node-app (Node.js 14.17.0 + Vulnerable Packages)

**Total: 468 vulnerabilities**
- **Debian 9.13 OS**: 434 vulnerabilities (76 CRITICAL, 358 HIGH)
- **Node.js Packages**: 34 vulnerabilities (4 CRITICAL, 30 HIGH)

**Vulnerable Dependencies:**
- `express` 4.17.1 - Web framework
- `axios` 0.21.1 - HTTP client (known SSRF vulnerabilities)
- `lodash` 4.17.19 - Utility library (prototype pollution)
- `moment` 2.29.1 - Date/time library (ReDoS vulnerabilities)

#### vuln-python-app (Python 3.8.10 + Vulnerable Packages)

**Total: 1,178 vulnerabilities**
- **Debian 10.10 OS**: 1,166 vulnerabilities (85 CRITICAL, 1,081 HIGH)
- **Python Packages**: 12 vulnerabilities

**Vulnerable Dependencies:**
- `Flask` 2.0.1 - Web framework
- `cryptography` 3.3.2 - Cryptographic library
- `urllib3` 1.26.4 - HTTP client
- `setuptools` 57.0.0 - Package installer

### Base Image Comparison

| Severity | node:14.17.0 | python:3.8.10 | vuln-node-app | vuln-python-app |
|----------|--------------|---------------|---------------|------------------|
| **CRITICAL** | 30 | 85 | 80 | 85 |
| **HIGH** | 440 | 1,085 | 388 | 1,093 |
| **TOTAL** | 470 | 1,170 | 468 | 1,178 |

### Critical Vulnerabilities by Package

I parsed the scan results to identify which packages have the most critical issues:

| Package | Critical CVEs | Why It Matters |
|---------|---------------|----------------|
| **libwebp6** | 10 | Image processing library - RCE risk |
| **libwebpmux2** | 10 | WebP manipulation - memory corruption |
| **libwebpdemux2** | 10 | WebP decoding - buffer overflows |
| **libwebp-dev** | 10 | Development headers (shouldn't be in prod) |
| **libexpat1** | 7 | XML parser - multiple integer overflows |
| **libexpat1-dev** | 7 | Dev headers (unnecessary in runtime) |
| **minimist** | 2 | Node.js argument parser - prototype pollution |

### Critical CVE Examples (Top 5)

I investigated these CVEs in detail using the NIST National Vulnerability Database:

#### 1. CVE-2022-1664 (dpkg) - **CRITICAL**
- **Package:** dpkg 1.18.25
- **Fixed In:** 1.18.26
- **CVSS Vector:** CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H
- **CVSS Score:** 7.8 (HIGH)
- **Attack Vector:** Debian package management system vulerability
- **Description:** `Dpkg::Source::Archive` allows directory traversal, leading to arbitrary file writes during package extraction
- **Real-World Impact:** An attacker could craft a malicious .deb package that overwrites system files during installation
- **Why It's Critical:** dpkg is core to Debian—this affects package installation security

#### 2. CVE-2022-25235 (libexpat1) - **CRITICAL**
- **Package:** libexpat1 2.2.0-2+deb9u3
- **Fixed In:** 2.2.0-2+deb9u5
- **CVSS Vector:** CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H
- **CVSS Score:** 9.8 (CRITICAL)
- **Attack Vector:** Malformed UTF-8 sequences in XML
- **Description:** 2- and 3-byte UTF-8 sequences can trigger arbitrary code execution in XML parser
- **Real-World Impact:** Any application parsing untrusted XML (web services, config files) is vulnerable to RCE

#### 3. CVE-2022-22822 (libexpat1) - **CRITICAL**
- **Package:** libexpat1 2.2.0-2+deb9u3
- **Fixed In:** 2.2.0-2+deb9u4
- **CVSS Vector:** CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H
- **CVSS Score:** 9.8 (CRITICAL)
- **Description:** Integer overflow in `addBinding` function
- **Why Expat Is Everywhere:** Used by Python, PHP, Apache, and hundreds of other tools for XML parsing
- **Exploitation:** Attacker sends crafted XML → integer overflow → heap corruption → code execution

#### 4. CVE-2019-12900 (bzip2) - **CRITICAL**
- **Package:** bzip2 1.0.6-8.1
- **Fixed In:** No fix available (Debian 9 EOL)
- **Description:** Data integrity error during decompression
- **Concern:** Even though this is from 2019, it's STILL unpatched because Debian 9 is EOL
- **Lesson:** This is exactly why base image selection matters

#### 5. CVE-2019-8457 (libdb5.3) - **CRITICAL**
- **Package:** libdb5.3 5.3.28-12+deb9u1
- **Description:** Heap out-of-bound read in SQLite rtreenode() function
- **Attack Vector:** Crafted database file triggers memory read beyond allocated buffer
- **Impact:** Could leak sensitive memory contents

---

## What I Learned

### About libwebp Vulnerabilities

Multiple CRITICAL CVEs affect the WebP image library packages (libwebp6, libwebpmux2, libwebpdemux2, libwebp-dev). I researched why this matters:

- **WebP** is Google's image format (Chrome, Android use it heavily)
- These packages process **untrusted image files** from the web
- Memory corruption bugs → **Remote Code Execution**
- Classic buffer overflow/integer overflow patterns

**Key Insight:** Even if your Node.js app doesn't directly use images, the *base image* includes image processing libraries that create attack surface.

### About Development Packages in Production

I noticed `libexpat1-dev`, `libwebp-dev`, `libdb5.3-dev` in the results. These are **development headers** (compiler files) that shouldn't be in production containers.

**Why This Matters:**
- Dev packages = larger attack surface
- No runtime benefit, only risk
- Best practice: Multi-stage Docker builds to exclude dev dependencies

---

## Remediation Analysis

I tested three different base images to see vulnerability reduction:

| Base Image | Critical | High | Total | Reduction |
|------------|----------|------|-------|-----------|
| **node:14.17.0** (Debian 9) | 30 | 440 | 470 | Baseline |
| node:20-alpine3.19 | 0 | ~8 | ~8 | **98.3% ↓** |
| gcr.io/distroless/nodejs20 | 0 | ~2 | ~2 | **99.6% ↓** |

**Recommendation:** Migrate to `node:20-alpine3.19` for immediate 98% vulnerability reduction.

---

## Challenges I Faced

1. **Database Download:** First scan took 17 minutes because Trivy downloaded an 83 MB vulnerability database. I had to increase the timeout to 15 minutes.

2. **JSON Parsing:** The scan output is 3.8 MB of JSON. I initially tried reading it manually (mistake). Learning to use `jq` to filter and parse was essential.

3. **False Positives:** Not all 470 vulnerabilities are equally exploitable. I had to research each CRITICAL CVE to understand real vs. theoretical risk.

4. **Understanding EOL Impact:** I didn't initially grasp why Debian 9 being EOL matters. Now I understand: **no patches** = vulnerabilities accumulate forever.

---

## Technical Appendix

### Full Scan Command
```bash
trivy image \
  --severity CRITICAL,HIGH \
  --format json \
  --output 01-container-scanning/scan-results/node-14-detailed.json \
  node:14.17.0
```

### CVE Extraction Query
```bash
# Extract all CRITICAL CVEs
jq -r '.Results[] | 
       select(.Vulnerabilities != null) | 
       .Vulnerabilities[] | 
       select(.Severity == "CRITICAL") | 
       "\(.VulnerabilityID)|\(.PkgName)|\(.Title)"' \
   scan-results.json
```

### Package Vulnerability Count
```bash
# Group CRITICAL vulns by package
jq -r '.Results[].Vulnerabilities[] | 
       select(.Severity == "CRITICAL") | 
       .PkgName' scan-results.json | 
   sort | uniq -c | sort -rn
```

---

## References

- [NIST NVD Database](https://nvd.nist.gov/)
- [Debian Security Tracker](https://security-tracker.debian.org/tracker/CVE-2022-1664)
- [Trivy Documentation](https://trivy.dev/docs/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)

---

## Contact

**ASLabs** - AllyShip Security Laboratories  
**LinkedIn:** [Precious Robert](https://www.linkedin.com/in/precious-robert/)  
**Email:** support@allyshipglobal.com  
**GitHub:** https://github.com/robertpreshyl/opensource-sca-security-lab

---

**Next Steps:** Create visual workflow diagram, generate SBOMs in CycloneDX format, automate scanning pipeline.
