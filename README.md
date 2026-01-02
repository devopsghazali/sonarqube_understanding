# SonarQube Installation, Debugging & System Troubleshooting  
### NetworkJung DevOps Lab — Real-World Debugging Log

This document is a **real DevOps lab log**, written while actually installing and fixing SonarQube on a low-RAM system.

Nothing here is theoretical.  
Every command was executed because something **broke**.

---

## Lab Environment Reality

A single VM was used as a DevOps lab and already running multiple heavy services:

- SonarQube
- PostgreSQL
- Jenkins
- Kubernetes (control plane)
- Grafana

Running all of these on one machine exposed **real resource limits, kernel limits, and service dependency failures**, which are documented below exactly as they occurred.

---

## SonarQube System User Setup

SonarQube is a long-running Java service and should never be executed as `root`.

A restricted system user was created:

```bash
sudo adduser --system --no-create-home --group --disabled-login sonarqube
This user has no shell, no home directory, and exists only to run SonarQube processes.
All SonarQube services run under this account to follow least-privilege security.

PostgreSQL Setup for SonarQube
SonarQube requires a persistent database. PostgreSQL is the recommended backend.

A PostgreSQL role and database were created:

sql
Copy code
CREATE ROLE sonaruser WITH LOGIN PASSWORD 'sonaruser';
CREATE DATABASE sonaruser OWNER sonaruser;
Verification was done using:

sql
Copy code
\du
\l
This clarified an important concept early on:
PostgreSQL roles (users) and databases are separate objects, even if they share the same name.

PostgreSQL Authentication Issue (Peer vs Password)
Initial login attempts failed due to PostgreSQL using peer authentication by default.

Peer authentication only works when:

Linux OS user name = PostgreSQL user name

SonarQube does not log in using peer auth.
Applications connect using TCP + username + password.

Manual verification was done exactly the same way SonarQube would connect:

bash
Copy code
psql -h localhost -U sonaruser -d sonaruser
Once this command worked, the database side was confirmed healthy.

SonarQube Database Configuration
Database configuration was set in:

swift
Copy code
/opt/sonarqube/conf/sonar.properties
Configuration used:

properties
Copy code
sonar.jdbc.username=sonaruser
sonar.jdbc.password=sonaruser
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonaruser
This confirmed:

Database name: sonaruser

Database user: sonaruser

Connection type: TCP (not socket, not peer)

SonarQube Started but UI Not Opening
SonarQube service showed as running:

bash
Copy code
systemctl status sonarqube
But the UI did not open in the browser.

Port check:

bash
Copy code
ss -tulnp | grep 9000
Result: no output

This meant:

Service started

Web server never reached ready state

Elasticsearch Failure (Actual Root Cause)
SonarQube depends on embedded Elasticsearch.
If Elasticsearch fails, the web server never opens port 9000.

Logs were checked:

bash
Copy code
sudo tail -n 100 /opt/sonarqube/logs/es.log
Critical error found:

arduino
Copy code
bootstrap check failure:
max virtual memory areas vm.max_map_count [65530] is too low
Linux default kernel limit was insufficient.
Elasticsearch refused to start, silently blocking the SonarQube UI.

Fixing vm.max_map_count
Temporary fix:

bash
Copy code
sudo sysctl -w vm.max_map_count=262144
Permanent fix:

bash
Copy code
sudo nano /etc/sysctl.conf
Add:

ini
Copy code
vm.max_map_count=262144
Apply:

bash
Copy code
sudo sysctl -p
Restart SonarQube:

bash
Copy code
sudo systemctl restart sonarqube
Port verification:

bash
Copy code
ss -tulnp | grep 9000
Expected output:

nginx
Copy code
LISTEN 0 50 0.0.0.0:9000 java
SonarQube UI became accessible:

cpp
Copy code
http://<server-ip>:9000
Default login:

pgsql
Copy code
admin / admin
RAM Analysis (Realistic View)
System memory was checked using:

bash
Copy code
free -h
Key rule applied:

Ignore used

Focus only on available

Process-wise memory usage:

bash
Copy code
ps -eo user,%mem,comm --sort=-%mem | head -10
Multiple Java processes appeared for SonarQube, along with Jenkins, PostgreSQL, and Grafana.

This confirmed that SonarQube does not run as a single Java process.
It runs multiple components:

Elasticsearch

Web Server

Compute Engine

High memory usage is expected behavior.

Critical State: Only 131 MB RAM Available
At one point, available memory dropped to ~131 MB, indicating an unstable system.

Immediate cleanup actions:

bash
Copy code
sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches
Heavy services not required immediately were stopped:

bash
Copy code
sudo systemctl stop kubelet
sudo systemctl stop containerd
sudo systemctl stop jenkins
This freed a significant amount of RAM.

Reducing SonarQube Memory Usage
SonarQube Java heap sizes were reduced in sonar.properties:

properties
Copy code
sonar.search.javaOpts=-Xms256m -Xmx256m
sonar.web.javaOpts=-Xms256m -Xmx256m
sonar.ce.javaOpts=-Xms128m -Xmx128m
Changes applied:

bash
Copy code
sudo systemctl restart sonarqube
Swap File for Stability
To prevent crashes under memory pressure, swap was enabled:

bash
Copy code
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
Verification:

bash
Copy code
swapon --show
Swap was used only as a safety buffer, not as performance memory.

Final Stable Lab State
On a low-RAM system, the stable configuration was:

SonarQube → running

PostgreSQL → running

Jenkins → stopped when idle

Kubernetes → stopped

Grafana → optional

Trying to run everything together on one VM consistently caused instability.

Lessons Learned (Straight From the Lab)
A running service does not mean it is ready

Logs always expose the real issue

Elasticsearch failures block SonarQube silently

Memory problems are architectural, not command-level

One VM cannot safely host all heavy DevOps tools at once

Author
Hasnain Ghazali
DevOps | Cloud | Linux | CI/CD

GitHub: devopshasnain
