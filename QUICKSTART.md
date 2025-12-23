# Quick Start Guide - Drupal 8 to 11 Upgrade Test Bed

## Current Status: Phase 1 - Drupal 8.9 Installation

### ✅ What's Running
- **Kubernetes**: Docker Desktop (single-node cluster)
- **PostgreSQL**: Running in `drupal` namespace (via Helm)
- **Drupal 8.9**: Running in `drupal` namespace (via Kubernetes manifests)
- **Port Forward**: http://localhost:8080 (active in background)

### 🚀 Access Drupal
Drupal is accessible at: **http://localhost:8080**

The browser should already be open. If not:
```bash
open http://localhost:8080
```

### 📋 Installation Steps (in Browser)
1. Choose **Standard** installation profile
2. Database configuration:
   - **Database type**: PostgreSQL
   - **Database name**: `drupal`
   - **Database username**: `drupal`
   - **Database password**: `drupal123`
   - **Advanced Options**:
     - **Host**: `postgresql.drupal.svc.cluster.local`
     - **Port**: `5432`
3. Site configuration:
   - **Site name**: Drupal 8 Test Bed
   - **Site email**: admin@example.com
   - **Username**: admin
   - **Password**: (choose a password)
   - **Email**: admin@example.com
4. Click **Install**

### 🔍 Useful Commands

#### Check Running Pods
```bash
kubectl get pods -n drupal
```

#### Access Drupal Pod
```bash
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $DRUPAL_POD -n drupal -- bash
```

#### Check Drupal Logs
```bash
kubectl logs -n drupal -l app=drupal -f
```

#### Create Backup
```bash
./scripts/backup.sh
```

#### Restart Port Forward (if needed)
```bash
# Kill existing port-forward
pkill -f "port-forward.*drupal"

# Start new port-forward
kubectl port-forward -n drupal svc/drupal 8080:80
```

### 📁 Project Structure
```
drupal_update/
├── helm/                 # Helm values
│   ├── values-d8.yaml   # (deprecated, using manifests instead)
│   └── postgresql-values.yaml
├── kubernetes/           # Kubernetes manifests
│   └── drupal-d8.yaml   # Current Drupal 8 deployment
├── backups/              # Database backups
└── scripts/              # Automation scripts
    └── backup.sh        # Database backup script
```

### 🔄 Next Steps After Installation
1. Complete Drupal installation via web UI
2. Create sample content (articles, pages)
3. Install contrib modules (optional): admin_toolbar, devel
4. Export configuration: `drush config:export -y`
5. Create baseline backup: `./scripts/backup.sh`
6. Ready for Phase 2 (upgrade to Drupal 9)

### 🛠️ Troubleshooting

#### Port-forward not working?
```bash
# Check if port-forward is running
ps aux | grep port-forward

# Restart it
pkill -f "port-forward.*drupal"
kubectl port-forward -n drupal svc/drupal 8080:80
```

#### Can't connect to database?
```bash
# Check PostgreSQL is running
kubectl get pods -n drupal

# Test database connection
kubectl run psql-test --rm -it --restart=Never --namespace drupal \
  --image postgres:15 --env="PGPASSWORD=drupal123" \
  -- psql -h postgresql.drupal.svc.cluster.local -U drupal -d drupal
```

#### Pods not starting?
```bash
# Check pod status
kubectl describe pod -n drupal <pod-name>

# Check events
kubectl get events -n drupal --sort-by='.lastTimestamp'
```

### 🧹 Cleanup (if needed)
```bash
# Delete Drupal deployment
kubectl delete -f kubernetes/drupal-d8.yaml

# Uninstall PostgreSQL
helm uninstall postgresql -n drupal

# Delete namespace (removes everything)
kubectl delete namespace drupal
```
