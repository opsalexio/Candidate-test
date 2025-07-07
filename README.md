Create a virtual machine (VM) in Azure on which a minimal container environment is set up. On it, deploy a
Keycloak container and an attached Postgres database, as well as a web server with a static web page whose
access is controlled by the Keycloak.

Implementation:  
- The project is to be implemented on GitHub.  
    • Creation according to the Git workflow  
    • Creation of minimal but meaningful documentation (with architecture)  
- Creation of all infrastructure components is to be done using Terraform.  
    • Creation of necessary managed identities/service principals is not part of the task.  
- All infrastructure configurational work should be done using Ansible wherever possible.  
- Create GitHub Actions that will:  
    • roll out  
    • configure  
    • and disassemble the project.   


How to use this repository:

1. Prerequisites Setup

# Terraform
brew install terraform
# Azure CLI
brew install azure-cli
# Ansible
brew install ansible
# GitHub CLI (optional)
brew install gh
# Azure auth
az login
az ad sp create-for-rbac --name "keycloak-infra" --role Contributor --scopes /subscriptions/YOUR_SUB_ID --sdk-auth

2. Repository setup

git clone https://github.com/your-repo/keycloak-azure-infra.git
cd keycloak-azure-infra

3. GitHub Actions Deployment

Go to Repository Settings → Secrets:
Add AZURE_CREDENTIALS (from Step 1)
Add ANSIBLE_VAULT_PASSWORD

GitHub UI: Actions → Keycloak Infrastructure → Run workflow

4. Accessing Resources

Keycloak Admin Console:

http://<PUBLIC_IP>:8080
Credentials: admin/changeme (change in Ansible vars)

Static Website:
http://<PUBLIC_IP>

SSH Access:
ssh -i terraform/ansible/keys/keycloak_ssh adminuser@<PUBLIC_IP>

5. Post-Deployment Checklist

Change default Keycloak credentials

Configure TLS in Nginx (ansible/templates/nginx.conf.j2)

Set up monitoring (Azure Monitor or Prometheus)

Enable backups for Postgres data


- Justify your choice:  

    ▪ of the components used:  
        Component   Why Chose It	                        Alternative Considered	            Why Not Chosen
        Keycloak    Free open-source auth with OIDC/SAML	Auth0/Okta	                        Too expensive
        PostgreSQL	Works best with Keycloak's queries	    MySQL	                            Less optimized
        Nginx	    Lightweight & handles auth well	        Apache/Traefik	                    Too heavy/complex
        Azure VM	Good for mid-size projects	            Kubernetes	                        Overkill for 1 service

    • Why were the components created?  
    - This architecture uses Keycloak for secure authentication (open-source alternative to paid solutions like Auth0), PostgreSQL as its optimized database, and Nginx as a lightweight reverse proxy. We chose Azure VMs over Kubernetes for simplicity in this small-scale deployment. Official container images ensure security, while the network setup balances accessibility and basic protection. The design prioritizes essential components only - no service meshes or managed databases - to maintain simplicity without compromising core functionality.
    • Why did you not use other components?  

    ▪ the images used:
    - quay.io/keycloak/keycloak:latest -> Latest stable with automatic updates	-> Official RH-certified image with regular CVE patches
    - postgres:13	-> LTS version with long-term support	-> Scanned for vulnerabilities in Docker Hub
    Why Not Other Images?
    - Avoided :edge tags (unstable)
    - Rejected Alpine variants (incompatible with Keycloak's Java requirements)
    - Skipped custom builds (maintenance burden)


    ▪ the network configuration  

    Network Traffic Flow:

    - Public Internet Access
        All traffic enters through Azure's Network Security Group (NSG) firewall

    - NSG Rule Handling
        The NSG directs traffic based on port:
        *HTTP/HTTPS (Port 80/443)* → Routes to Nginx reverse proxy
        SSH (Port 22) → Allows secure VM administration
        Keycloak Admin (Port 8080) → Direct access to Keycloak console

    - Nginx Processing
        The reverse proxy handles two paths:
        Static Content: Serves regular web pages directly
        /secured: Validates credentials via Keycloak before granting access

    - Security Boundaries:
        Public-facing ports are minimized (80,443,22,8080 only)
        All authentication flows through Keycloak's dedicated port
        SSH access is restricted by NSG rules


    Security Tradeoffs Made:
    - Public IP Required: For demo accessibility (production should use Bastion)
    - Port 8080 Exposed: Necessary for Keycloak admin (should be IP-restricted in prod)
    - Single Subnet: Simplified architecture (multi-tier would add complexity without benefits here)
    Why Not Alternative Configs?
    - No Private Link: Added cost/complexity without value for this use case
    - No WAF: Static content doesn't need web application firewall
    - No Service Mesh: Only Postgres→Keycloak communication 

  ▪ Justify the choice of the container environment. 
    
    - Why Not Use Serverless/Managed Services?
        Keycloak requires persistent storage (not ideal for serverless).
        Managed PostgreSQL (e.g., Azure DB) adds cost (~$50+/month vs. $0 for self-hosted).
        More control over networking & security when self-hosted.
    - Tradeoffs Made:
        Pros: Lightweight (low resource overhead), fast deployment, easy to destroy/recreate for testing.
        Cons: No auto-healing (mitigated by systemd/restart policies), manual backups needed (mitigated by cron jobs/Azure Backup), 
        
  ▪ Name possible features that extend the project and describe the benefits of the features added.  
    Possible Feature Extensions & Their Benefits
    - HTTPS/TLS Encryption with Let’s Encrypt
    Adding automated SSL certificates via Certbot or Traefik would secure all web traffic between users and the application. This prevents man-in-the-middle attacks, ensures data privacy, and improves trust (especially important for authentication systems like Keycloak).

    -  High Availability (HA) with Multiple Keycloak Instances
    Deploying Keycloak in a cluster (2+ instances) with a load balancer would eliminate single points of failure. This ensures uninterrupted access even if one VM crashes, making the system production-ready for enterprise use.

    -  Automated Backups for PostgreSQL
    Implementing scheduled backups (using pg_dump + Azure Blob Storage) would protect against data loss. This is critical for production environments where losing user credentials would be catastrophic.

    -  Monitoring with Prometheus + Grafana
    Adding real-time monitoring for CPU, memory, and Keycloak login metrics would help detect performance bottlenecks or attacks (e.g., brute-force attempts). This improves operational visibility and proactive maintenance.

    -  IP Whitelisting for Admin Access
    Restricting Keycloak’s admin console (port 8080) to specific IPs (e.g., office VPN) would prevent unauthorized access attempts, significantly improving security.

    -  Integration with External Identity Providers (e.g., Google, Azure AD)
    Allowing users to log in via social logins or corporate SSO (SAML/OIDC) would improve usability and reduce password fatigue. This is essential for modern applications.

    -  Rate Limiting & Brute-Force Protection
    Adding fail2ban or Nginx rate limiting would block repeated login attempts, protecting against credential stuffing attacks.

    -  Terraform Remote State with Azure Storage
    Storing Terraform state in Azure Blob Storage (instead of locally) enables team collaboration and prevents accidental state file loss.

    - Multi-Tier Network Isolation
    Separating frontend (Nginx), backend (Keycloak), and database (PostgreSQL) into different subnets with strict NSG rules would follow defense-in-depth principles, limiting lateral movement in case of a breach.
  ▪ Why These Extensions Matter
    - Each feature addresses a critical gap in security, reliability, or usability. For example:
    - HTTPS prevents eavesdropping.
    - HA ensures uptime for mission-critical auth systems.
    - Backups guarantee disaster recovery.
    - These upgrades would transform the project from a demo into a production-grade identity management system.