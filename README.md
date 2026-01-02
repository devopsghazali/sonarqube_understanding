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

# SonarQube Installation, Debugging & System Troubleshooting
NetworkJung DevOps Lab — Real-World Debugging Log

A dedicated system user was created for running SonarQube because it is a long-running Java service and must never run as root.

Command used:
sudo adduser --system --no-create-home --group --disabled-login sonarqube

This user has no shell, no home directory, and exists only to run SonarQube processes.
All SonarQube services run under this account to follow the least-privilege security model.

SonarQube requires a persistent database, and PostgreSQL is the recommended backend.
A PostgreSQL role and database were created as follows:

CREATE ROLE sonaruser WITH LOGIN PASSWORD 'sonaruser';
CREATE DATABASE sonaruser OWNER sonaruser;

Verification was done using:
\du
\l

This clarified an important concept early on:
PostgreSQL roles (users) and databases are separate objects, even if they share the same name.

Initial login attempts failed due to PostgreSQL using peer authentication by default.
Peer authentication only works when the Linux OS user name and PostgreSQL user name are the same.

SonarQube does not use peer authentication.
Applications connect using TCP with a username and password.

Manual verification was done exactly the same way SonarQube connects:

psql -h localhost -U sonaruser -d sonaruser

Once this command worked, the database layer was confirmed healthy.

Database configuration for SonarQube was set in:
/opt/sonarqube/conf/sonar.properties

Configuration used:
sonar.jdbc.username=sonaruser
sonar.jdbc.password=sonaruser
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonaruser

This confirmed that:
Database name is sonaruser
Database user is sonaruser
Connection type is TCP, not socket and not peer authentication

After starting SonarQube, the service appeared to be running:
systemctl status sonarqube

However, the UI did not open in the browser.

Port verification:
ss -tulnp | grep 9000

There was no output, which meant the service had started but the web server never reached a ready state.

SonarQube depends on embedded Elasticsearch.
If Elasticsearch fails, the SonarQube web server never opens port 9000.

Elasticsearch logs were inspected:
sudo tail -n 100 /opt/sonarqube/logs/es.log

The critical error found was:
bootstrap check failure:
max virtual memory areas vm.max_map_count [65530] is too low

The Linux default kernel limit was insufficient.
Elasticsearch refused to start, silently blocking the SonarQube UI.

Temporary fix applied:
sudo sysctl -w vm.max_map_count=262144

Permanent fix applied by editing:
/etc/sysctl.conf

Added line:
vm.max_map_count=262144

Changes applied using:
sudo sysctl -p

SonarQube was restarted:
sudo systemctl restart sonarqube

Port verification after restart:
ss -tulnp | grep 9000

Expected output indicated Java listening on port 9000.

SonarQube UI became accessible at:
http://<server-ip>:9000

Default login credentials:
admin / admin

System memory was analyzed using:
free -h

The key rule followed was to ignore the used column and focus only on available memory.

Process-wise memory usage was checked using:
ps -eo user,%mem,comm --sort=-%mem | head -10

Multiple Java processes appeared for SonarQube, along with Jenkins, PostgreSQL, and Grafana.

This confirmed that SonarQube does not run as a single Java process.
It runs multiple components:
Elasticsearch
Web Server
Compute Engine

High memory usage is expected behavior.

At one point, available memory dropped to around 131 MB, indicating an unstable system state.

Immediate cleanup actions were taken:
sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches

Heavy services not required immediately were stopped:
sudo systemctl stop kubelet
sudo systemctl stop containerd
sudo systemctl stop jenkins

This freed a significant amount of RAM.

SonarQube Java heap sizes were reduced in sonar.properties:
sonar.search.javaOpts=-Xms256m -Xmx256m
sonar.web.javaOpts=-Xms256m -Xmx256m
sonar.ce.javaOpts=-Xms128m -Xmx128m

Changes were applied by restarting SonarQube:
sudo systemctl restart sonarqube

To prevent crashes under memory pressure, swap was enabled:
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

Verification was done using:
swapon --show

Swap was used only as a safety buffer and not as performance memory.

On a low-RAM system, the stable configuration was:
SonarQube running
PostgreSQL running
Jenkins stopped when idle
Kubernetes stopped
Grafana optional

Trying to run all heavy DevOps tools together on one VM consistently caused instability.

Lessons learned from the lab:
A running service does not mean it is ready.
Logs always expose the real issue.
Elasticsearch failures silently block SonarQube.
Memory problems are architectural, not command-level.
One VM cannot safely host all heavy DevOps tools at once.

Author:
Hasnain Ghazali
DevOps | Cloud | Linux | CI/CD
GitHub: devopshasnain

