#!/bin/bash
set -e

echo "==============================================="
echo " DevSecOps Security Tools Installation Started "
echo " Host: $(hostname)"
echo "==============================================="

# ---------- COMMON ----------
echo "[+] Updating system & base packages"
sudo apt update -y
sudo apt install -y \
  wget \
  unzip \
  curl \
  gnupg \
  lsb-release \
  ca-certificates \
  openjdk-17-jre

# ---------- GITLEAKS ----------
echo "-----------------------------------------------"
echo "[+] Installing Gitleaks (binary)"
echo "-----------------------------------------------"

GITLEAKS_VERSION="8.30.0"

if command -v gitleaks >/dev/null 2>&1; then
  echo "[✓] Gitleaks already installed"
else
  cd /tmp
  wget https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_amd64.deb
  sudo dpkg -i gitleaks_${GITLEAKS_VERSION}_linux_amd64.deb
  sudo apt -f install -y
fi

gitleaks version

# ---------- SONAR-SCANNER CLI ----------
echo "-----------------------------------------------"
echo "[+] Installing Sonar-Scanner CLI (binary)"
echo "-----------------------------------------------"

SONAR_VERSION="7.0.1.4817"

if command -v sonar-scanner >/dev/null 2>&1; then
  echo "[✓] Sonar-Scanner already installed"
else
  cd /tmp
  wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_VERSION}-linux-x64.zip
  unzip sonar-scanner-cli-${SONAR_VERSION}-linux-x64.zip
  sudo mv sonar-scanner-${SONAR_VERSION}-linux-x64 /opt/sonar-scanner
  sudo ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
fi

sonar-scanner --version

# ---------- TRIVY ----------
echo "-----------------------------------------------"
echo "[+] Installing Trivy (filesystem + image scan)"
echo "-----------------------------------------------"

if command -v trivy >/dev/null 2>&1; then
  echo "[✓] Trivy already installed"
else
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
  echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list
  sudo apt update -y
  sudo apt install -y trivy
fi

trivy --version

# ---------- OWASP DEPENDENCY-CHECK ----------
echo "-----------------------------------------------"
echo "[+] Installing OWASP Dependency-Check (binary)"
echo "-----------------------------------------------"

DC_VERSION="9.0.9"

if command -v dependency-check.sh >/dev/null 2>&1; then
  echo "[✓] Dependency-Check already installed"
else
  cd /tmp
  wget https://github.com/jeremylong/DependencyCheck/releases/download/v${DC_VERSION}/dependency-check-${DC_VERSION}-release.zip
  unzip dependency-check-${DC_VERSION}-release.zip
  sudo mv dependency-check /opt/dependency-check
  sudo ln -s /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check.sh
  sudo chmod +x /opt/dependency-check/bin/dependency-check.sh
fi

dependency-check.sh --version

# ---------- DOCKER CHECK (for image scan) ----------
echo "-----------------------------------------------"
echo "[+] Checking Docker availability (for Trivy image scan)"
echo "-----------------------------------------------"

if command -v docker >/dev/null 2>&1; then
  docker --version
  echo "[✓] Docker available → image scanning READY"
else
  echo "[!] Docker NOT installed"
  echo "    Trivy image scan will work only after Docker install"
fi

echo "==============================================="
echo " DevSecOps Security Tools Installation Complete "
echo "==============================================="
