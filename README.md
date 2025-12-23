# Drupal 8 to 11 Upgrade Test Bed

A step-by-step testing environment for upgrading Drupal from version 8.9 to 11.x using Kubernetes and Helm, designed to mirror production deployment practices.

## 📋 Project Overview

This repository documents and tests the complete upgrade path for Drupal:
- **Starting Point**: Drupal 8.9.20 with PostgreSQL
- **Target**: Drupal 11.x
- **Infrastructure**: Kubernetes (Docker Desktop) + Helm
- **Database**: PostgreSQL 15
- **Purpose**: Test bed to validate upgrade procedures before applying to production

## 🏗️ Architecture

- **Orchestration**: Kubernetes via Docker Desktop
- **Database**: PostgreSQL deployed via Bitnami Helm chart
- **Drupal**: Deployed via Kubernetes manifests
- **Storage**: Persistent volumes for database and Drupal files
- **Access**: Port-forwarding to localhost:8080

## 📂 Repository Structure

```
drupal_update/
├── helm/                 # Helm values files
│   └── postgresql-values.yaml  # PostgreSQL configuration
├── kubernetes/           # Kubernetes manifests
│   └── drupal-d8.yaml    # Drupal 8 deployment
├── scripts/              # Automation scripts
│   └── backup.sh         # Database backup script
├── backups/              # Database and config backups
├── QUICKSTART.md         # Quick reference guide
└── README.md             # This file
```

## 🏷️ Git Tags and Phases

This project uses git tags to mark each phase of the upgrade process:

- `v1.0-drupal-8.9` - Initial Drupal 8.9 installation ← **Current Phase**
- `v2.0-drupal-9.5` - Upgraded to Drupal 9.5 (planned)
- `v3.0-drupal-10.3` - Upgraded to Drupal 10.3 (planned)
- `v4.0-drupal-11.x` - Upgraded to Drupal 11.x (planned)

Each tag represents a stable, working state that can be referenced or rolled back to.

## 🚀 Quick Start

### Prerequisites

- Docker Desktop with Kubernetes enabled
- Helm 3+ installed
- kubectl installed
- At least 4GB RAM allocated to Docker

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd drupal_update
   ```

2. **Enable Kubernetes in Docker Desktop**
   - Open Docker Desktop → Settings → Kubernetes
   - Check "Enable Kubernetes"
   - Apply & Restart

3. **Add Helm repository**
   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   ```

4. **Deploy PostgreSQL**
   ```bash
   helm install postgresql bitnami/postgresql -n drupal --create-namespace -f helm/postgresql-values.yaml
   ```

5. **Deploy Drupal 8**
   ```bash
   kubectl apply -f kubernetes/drupal-d8.yaml
   ```

6. **Access Drupal**
   ```bash
   kubectl port-forward -n drupal svc/drupal 8080:80
   ```
   
   Open http://localhost:8080 in your browser

7. **Complete Installation**
   - Choose **PostgreSQL** database
   - Database: `drupal`
   - Username: `drupal`
   - Password: `drupal123`
   - Host (in Advanced Options): `postgresql.drupal.svc.cluster.local`
   - Port: `5432`

## 📊 Current Status

### Phase 1: Drupal 8.9 Installation ✅

**Completed:**
- ✅ Kubernetes cluster configured
- ✅ PostgreSQL 15 deployed
- ✅ Drupal 8.9 deployed
- ✅ Persistent storage configured
- ✅ Backup scripts created
- ✅ Documentation complete

**What's Running:**
```bash
kubectl get pods -n drupal
```
Should show:
- `drupal-d8-xxx` (Drupal application)
- `postgresql-0` (PostgreSQL database)

## 🔧 Common Commands

### Check Status
```bash
# View all resources
kubectl get all -n drupal

# Check pods
kubectl get pods -n drupal

# View logs
kubectl logs -n drupal -l app=drupal -f
```

### Access Drupal Pod
```bash
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $DRUPAL_POD -n drupal -- bash
```

### Backup
```bash
./scripts/backup.sh
```

### Cleanup
```bash
# Delete Drupal
kubectl delete -f kubernetes/drupal-d8.yaml

# Uninstall PostgreSQL
helm uninstall postgresql -n drupal

# Delete namespace
kubectl delete namespace drupal
```

## 🔄 Upgrade Path

### Phase 1: Drupal 8.9.20 (Current)
- ✅ Fresh installation with PostgreSQL
- ✅ Sample content created
- ✅ Baseline backup created
- 🏷️ Tag: `v1.0-drupal-8.9`

### Phase 2: Drupal 9.5 (Next)
- Update Kubernetes manifest to Drupal 9 image
- Run database updates
- Verify functionality
- 🏷️ Tag: `v2.0-drupal-9.5`

### Phase 3: Drupal 10.3
- Update to Drupal 10 image
- PHP 8.2 compatibility
- Module updates
- 🏷️ Tag: `v3.0-drupal-10.3`

### Phase 4: Drupal 11.x
- Final upgrade to Drupal 11
- PHP 8.3 compatibility
- Performance optimization
- 🏷️ Tag: `v4.0-drupal-11.x`

## 🐛 Troubleshooting

### Port-forward not working
```bash
pkill -f "port-forward.*drupal"
kubectl port-forward -n drupal svc/drupal 8080:80
```

### Database connection failed
```bash
# Verify PostgreSQL is running
kubectl get pods -n drupal

# Test connection
kubectl run psql-test --rm -it --restart=Never --namespace drupal \
  --image postgres:15 --env="PGPASSWORD=drupal123" \
  -- psql -h postgresql.drupal.svc.cluster.local -U drupal -d drupal
```

### Pods stuck in pending
```bash
# Check events
kubectl get events -n drupal --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod -n drupal <pod-name>
```

## 🔄 Git Workflow

Each Drupal version follows this workflow:

1. **Create branch** from main:
   ```bash
   git checkout -b drupal-8.9.20
   ```

2. **Make changes** (deploy, configure, test)

3. **Create database backup**:
   ```bash
   # Backup will be at backups/db/drupal_<version>.sql
   ```

4. **Commit changes**:
   ```bash
   git add .
   git commit -m "Phase X: Drupal <version> installation/upgrade
   
   - Detailed changes
   - Database backup included"
   ```

5. **Push branch** and create Pull Request to main:
   ```bash
   git push origin drupal-8.9.20
   ```

6. **Merge PR** to main

7. **Create tag** after merge:
   ```bash
   git checkout main
   git pull
   git tag -a v1.0-drupal-8.9.20 -m "Drupal 8.9.20 baseline"
   git push origin v1.0-drupal-8.9.20
   ```

## 🤝 Contributing

This is a test bed project following the workflow above.

## 📝 License

Internal testing project.

## 🔗 References

- [Drupal Upgrade Documentation](https://www.drupal.org/docs/upgrading-drupal)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)

---

**Current Phase**: Phase 1 - Drupal 8.9 Installation  
**Last Updated**: December 23, 2024  
**Next Milestone**: Phase 2 - Upgrade to Drupal 9.5
