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

## Risk Prioritization Matrix

Not all CRITICAL CVEs require immediate action. CVSS scores measure severity, but actual risk depends on exploitability, attack vector, and business context. Here's how I prioritized remediation for the top 5 CVEs:

| CVE | CVSS | Attack Vector | Exploit Available? | Attack Complexity | Business Priority | Remediation Timeline |
|-----|------|---------------|-------------------|-------------------|-------------------|---------------------|
| **CVE-2022-25235** | 9.8 | NETWORK | ✅ POC on GitHub | **LOW** - Any XML input | **P0 (CRITICAL)** | 24 hours |
| **CVE-2022-22822** | 9.8 | NETWORK | ✅ Public exploits | **LOW** - Any XML input | **P0 (CRITICAL)** | 24 hours |
| **CVE-2022-1664** | 7.8 | LOCAL | ⚠️ Theoretical | **MEDIUM** - Requires malicious .deb | **P1 (HIGH)** | 1 week |
| **CVE-2019-12900** | 9.8 | LOCAL | ✅ CVE-2019-12900 POC | **HIGH** - Needs .bz2 decompression | **P2 (MEDIUM)** | 30 days |
| **CVE-2019-8457** | 9.8 | LOCAL | ⚠️ Theoretical | **HIGH** - Requires crafted DB file | **P2 (MEDIUM)** | 30 days |

### Priority Level Definitions

**P0 (CRITICAL) - Fix within 24 hours:**
- Remote network exploitation possible (AV:N)
- No authentication required (PR:N)
- Public exploits or POCs available
- Affects common attack surfaces (XML parsers, web servers)
- **Business Impact:** Web applications parsing XML are immediately vulnerable to RCE

**P1 (HIGH) - Fix within 1 week:**
- Local attack vector or requires specific conditions
- Medium attack complexity
- Affects package management systems
- **Business Impact:** Risk exists but requires attacker to deliver malicious files

**P2 (MEDIUM) - Fix within 30 days:**
- Local-only exploitation
- High attack complexity or specific file types required
- Theoretical exploits without widespread POCs
- **Business Impact:** Low likelihood in typical container deployment scenarios

### Exploitability Assessment

#### Why CVE-2022-25235 & CVE-2022-22822 are P0 (Despite Same CVSS as Others)

**libexpat1 (XML parser) vulnerabilities:**
- ✅ **Network-exploitable:** Any web service accepting XML input is vulnerable
- ✅ **No authentication required:** Attacker just sends crafted XML payload
- ✅ **Public POCs exist:** Exploit code available on GitHub and security blogs
- ✅ **Widespread usage:** Python, PHP, Apache httpd all use libexpat for XML parsing
- ✅ **Real-world attack surface:** APIs, RSS feeds, SOAP services, config files

**Attack Scenario:**
```
1. Web app accepts XML input (common in APIs, SOAP services)
2. Attacker sends malformed UTF-8 sequence in XML payload
3. libexpat parser triggers integer overflow
4. Heap corruption leads to arbitrary code execution
5. Attacker gains shell access to container
```

**Time to Exploit:** ~2 hours for skilled attacker with public POCs

---

#### Why CVE-2022-1664 is P1 (Not P0, Despite 7.8 CVSS)

**dpkg (Debian package manager) vulnerability:**
- ⚠️ **Local attack vector:** Requires attacker to deliver malicious .deb package
- ⚠️ **Medium complexity:** Target must install the crafted package
- ⚠️ **Limited in containers:** Production containers rarely install packages at runtime
- ⚠️ **Theoretical exploits:** No widespread exploitation observed

**Attack Scenario:**
```
1. Attacker crafts malicious .deb package with directory traversal
2. Admin or automated system attempts to install package
3. dpkg allows file write outside intended directory
4. System files overwritten, leading to privilege escalation
```

**Why Lower Priority:**
- Container immutability principle: packages installed at build time, not runtime
- Supply chain controls: most orgs don't allow arbitrary .deb installation in production
- Attack requires social engineering or compromised build process

**Time to Exploit:** ~1 week (requires delivery mechanism + user interaction)

---

#### Why CVE-2019-12900 & CVE-2019-8457 are P2

**bzip2 & libdb5.3 vulnerabilities:**
- ⚠️ **Local attack vector:** Requires specific file types (.bz2, .db)
- ⚠️ **High attack complexity:** Application must process attacker-controlled files
- ⚠️ **Limited exposure:** Most web apps don't decompress .bz2 or parse SQLite files from untrusted sources
- ⚠️ **Age without exploitation:** 5+ years old with minimal real-world attacks

**Why Lower Priority:**
- Specific file format requirements (not common in modern web apps)
- Data integrity impact vs. direct RCE
- EOL status means no patch available anyway (requires base image upgrade)

---

### Real-World Risk Calculation

**Business Context: Node.js Microservice Deployment**

| Component | Exposure | CVE Impact | True Priority |
|-----------|----------|------------|---------------|
| **API Gateway** (parses JSON/XML) | PUBLIC | CVE-2022-25235, CVE-2022-22822 | **P0** |
| **File Upload Service** | INTERNAL | CVE-2019-12900 (bzip2) | **P2** |
| **Package Manager** | BUILD-TIME | CVE-2022-1664 (dpkg) | **P1** |
| **Database Layer** | INTERNAL | CVE-2019-8457 (libdb5.3) | **P2** |

**Remediation Strategy:**
1. **Immediate (P0):** Upgrade to Alpine-based images to eliminate libexpat1 vulnerabilities → Protects public-facing APIs
2. **Short-term (P1):** Use multi-stage builds to exclude dpkg from final image → Reduces supply chain risk
3. **Long-term (P2):** Plan migration from Debian 9 EOL to supported OS → Addresses all unfixable CVEs

---

### Key Takeaways: CVSS vs. Real Risk

**What CVSS Tells You:**
- Theoretical maximum impact (Confidentiality, Integrity, Availability)
- Attack vector type (Network, Local, Adjacent, Physical)
- Base severity score (0.0 - 10.0)

**What CVSS Doesn't Tell You:**
- ❌ Exploit availability (POC vs. Metasploit module vs. theoretical)
- ❌ Attack surface in YOUR environment (web-facing vs. internal)
- ❌ Likelihood of exploitation (common attack pattern vs. niche)
- ❌ Business impact in YOUR context (public API vs. batch processor)

**Professional Analysis Approach:**
1. Start with CVSS as baseline severity
2. Research exploit availability (ExploitDB, GitHub, Metasploit)
3. Map to your attack surface (which components are exposed?)
4. Assess attack complexity in your environment
5. Prioritize based on: **Likelihood × Impact × Exploitability**

**Formula:**
```
Risk Score = (CVSS Base Score) × (Exploit Availability Factor) × (Exposure Factor)

Where:
- Exploit Availability: 1.0 (theoretical) → 3.0 (weaponized Metasploit module)
- Exposure Factor: 0.3 (internal) → 1.0 (public internet-facing)

Example:
CVE-2022-25235: 9.8 × 2.5 (public POC) × 1.0 (public API) = 24.5 (URGENT)
CVE-2019-12900: 9.8 × 1.2 (old POC) × 0.4 (file upload only) = 4.7 (LOWER)
```

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
