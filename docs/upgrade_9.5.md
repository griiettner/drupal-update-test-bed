# Drupal 8.9.20 → 9.5.x Upgrade Guide

**Date:** December 23, 2024  
**Environment:** Kubernetes (Docker Desktop) + PostgreSQL  
**Duration:** ~15-20 minutes

---

## Prerequisites

### Current State
- **Current Version:** Drupal 8.9.20
- **Target Version:** Drupal 9.5.x
- **PHP Version:** 7.4 → 8.0
- **Database:** PostgreSQL 15
- **Deployment:** Kubernetes manifests

### Required Tools
- `kubectl` - Kubernetes CLI
- `helm` - For PostgreSQL management
- Access to the Kubernetes cluster
- Git access for version control

### Pre-Upgrade Checklist
- [ ] Drupal 8.9.20 is running and accessible
- [ ] Database backup exists (`backups/db/drupal_8.9.20.sql`)
- [ ] Git branch created: `drupal-9.5.x`
- [ ] Maintenance mode enabled (optional for production)

---

## Step 1: Pre-Upgrade Backup

**Time:** ~2 minutes

### 1.1 Create Database Backup

```bash
# Get PostgreSQL pod name
POSTGRES_POD=$(kubectl get pod -n drupal -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")

# Create backup
kubectl exec -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=drupal123 pg_dump -U drupal drupal" > backups/db/drupal_8.9.20_pre-upgrade.sql

# Verify backup
ls -lh backups/db/
```

**Expected Output:**
```
-rw-r--r-- 1 user staff 9.9M Dec 23 01:20 drupal_8.9.20.sql
-rw-r--r-- 1 user staff 9.9M Dec 23 01:30 drupal_8.9.20_pre-upgrade.sql
```

### 1.2 Export Configuration (if Drush available)

```bash
# Get Drupal pod
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal -o jsonpath="{.items[0].metadata.name}")

# Try to export config (may not work if Drush not installed)
kubectl exec -n drupal $DRUPAL_POD -- bash -c "cd /var/www/html && if [ -f vendor/bin/drush ]; then vendor/bin/drush config:export -y; fi"
```

**Note:** This step may be skipped if Drush is not available in the container.

---

## Step 2: Update Kubernetes Manifest

**Time:** ~2 minutes

### 2.1 Verify Current Deployment

```bash
kubectl get deployment drupal-d8 -n drupal -o yaml | grep "image:"
```

**Expected Output:**
```yaml
image: drupal:8.9-php7.4-apache
```

### 2.2 Create New Manifest for Drupal 9

Create or update `kubernetes/drupal-d9.yaml`:

```bash
cp kubernetes/drupal-d8.yaml kubernetes/drupal-d9.yaml
```

Edit the file to change:
- Image: `drupal:8.9-php7.4-apache` → `drupal:9.5-php8.0-apache`
- Deployment name: `drupal-d8` → `drupal-d9`
- Labels: `version: "8.9"` → `version: "9.5"`

**Key changes in manifest:**
```yaml
# Line 42: Update deployment name
name: drupal-d9

# Line 45: Update version label
version: "9.5"

# Line 60: Update image
image: drupal:9.5-php8.0-apache
```

---

## Step 3: Apply Drupal 9 Deployment

**Time:** ~5-8 minutes (including image pull)

### 3.1 Apply New Deployment

```bash
kubectl apply -f kubernetes/drupal-d9.yaml
```

**Expected Output:**
```
persistentvolumeclaim/drupal-files unchanged
configmap/drupal-config unchanged
secret/drupal-secrets unchanged
deployment.apps/drupal-d9 created
service/drupal unchanged
```

### 3.2 Monitor Pod Creation

```bash
kubectl get pods -n drupal -w
```

**Wait for:**
- New `drupal-d9-xxx` pod to show `STATUS: Running` and `READY: 1/1`
- This may take 3-5 minutes for image download

**Expected Output:**
```
NAME                         READY   STATUS    RESTARTS   AGE
drupal-d8-xxx                1/1     Running   0          45m
drupal-d9-xxx                0/1     ContainerCreating   0          10s
postgresql-0                 1/1     Running   0          50m
...
drupal-d9-xxx                1/1     Running   0          3m
```

### 3.3 Scale Down Old Deployment

```bash
kubectl scale deployment drupal-d8 -n drupal --replicas=0
```

**Expected Output:**
```
deployment.apps/drupal-d8 scaled
```

---

## Step 4: Database Updates

**Time:** ~3-5 minutes

### 4.1 Access New Drupal Pod

```bash
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal,version=9.5 -o jsonpath="{.items[0].metadata.name}")
echo "Drupal 9 Pod: $DRUPAL_POD"
```

### 4.2 Run Database Updates via Web UI

**Option A: Via Web Interface**

1. Update port-forward to new service:
```bash
# Kill old port-forward
pkill -f "port-forward.*drupal"

# Start new port-forward
kubectl port-forward -n drupal svc/drupal 8080:80 &
```

2. Access: http://localhost:8080/update.php
3. Click "Continue" to run database updates
4. Wait for completion

**Option B: Via PHP Script (if web update fails)**

```bash
kubectl exec -n drupal $DRUPAL_POD -- bash -c "cd /var/www/html && php core/scripts/drupal update:update"
```

### 4.3 Clear All Caches

```bash
# Clear Drupal cache
kubectl exec -n drupal $DRUPAL_POD -- bash -c "rm -rf /var/www/html/sites/default/files/php/*"

# Restart pod to ensure clean state
kubectl delete pod $DRUPAL_POD -n drupal
```

**Wait for new pod to come up:**
```bash
kubectl get pods -n drupal -w
```

---

## Step 5: Verification

**Time:** ~3 minutes

### 5.1 Verify Drupal Version

```bash
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal,version=9.5 -o jsonpath="{.items[0].metadata.name}")
kubectl exec -n drupal $DRUPAL_POD -- cat /var/www/html/core/lib/Drupal.php | grep "const VERSION"
```

**Expected Output:**
```php
const VERSION = '9.5.x';
```

### 5.2 Access Web Interface

```bash
# Ensure port-forward is running
kubectl port-forward -n drupal svc/drupal 8080:80 &

# Open browser
open http://localhost:8080
```

**Verify:**
- [ ] Site loads successfully
- [ ] Can log in as admin
- [ ] Status report shows Drupal 9.5.x
- [ ] No critical errors
- [ ] Content is visible

### 5.3 Check Status Report

1. Go to: http://localhost:8080/admin/reports/status
2. Verify:
   - Drupal version: 9.5.x
   - PHP version: 8.0.x
   - Database: Connected
   - No critical errors

---

## Step 6: Post-Upgrade Steps

**Time:** ~3 minutes

### 6.1 Create Post-Upgrade Backup

```bash
POSTGRES_POD=$(kubectl get pod -n drupal -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")

kubectl exec -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=drupal123 pg_dump -U drupal drupal" > backups/db/drupal_9.5.x.sql

# Verify backup size
ls -lh backups/db/drupal_9.5.x.sql
```

**Expected:** File size similar to or slightly larger than 8.9 backup

### 6.2 Clean Up Old Deployment

```bash
# Delete old Drupal 8 deployment
kubectl delete deployment drupal-d8 -n drupal

# Verify only Drupal 9 is running
kubectl get deployments -n drupal
```

**Expected Output:**
```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
drupal-d9   1/1     1            1           15m
```

### 6.3 Update Documentation

- [ ] Commit changes to git
- [ ] Update README.md if needed
- [ ] Document any issues encountered

---

## Step 7: Git Workflow

**Time:** ~2 minutes

### 7.1 Commit Changes

```bash
git add .
git commit -m "Phase 2: Drupal 9.5.x upgrade

- Updated to drupal:9.5-php8.0-apache image
- Created new kubernetes/drupal-d9.yaml manifest
- Ran database updates successfully
- Database backup: backups/db/drupal_9.5.x.sql
- Verified functionality and status"

git push origin drupal-9.5.x
```

### 7.2 Create Pull Request

Create PR via GitHub/GitLab web interface.

### 7.3 After Merge: Create Tag

```bash
git checkout main
git pull
git tag -a v2.0-drupal-9.5 -m "Drupal 9.5.x upgrade - Working and verified"
git push origin v2.0-drupal-9.5
```

---

## Rollback Procedure

If the upgrade fails, follow these steps:

### Rollback Step 1: Restore Old Deployment

```bash
# Scale up Drupal 8 deployment
kubectl scale deployment drupal-d8 -n drupal --replicas=1

# Scale down Drupal 9 deployment
kubectl scale deployment drupal-d9 -n drupal --replicas=0

# Wait for pod to be ready
kubectl get pods -n drupal -w
```

### Rollback Step 2: Restore Database

```bash
POSTGRES_POD=$(kubectl get pod -n drupal -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")

# Drop current database
kubectl exec -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=postgres123 psql -U postgres -c 'DROP DATABASE drupal;'"

# Recreate database
kubectl exec -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=postgres123 psql -U postgres -c 'CREATE DATABASE drupal OWNER drupal;'"

# Restore backup
kubectl exec -i -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=drupal123 psql -U drupal drupal" < backups/db/drupal_8.9.20.sql
```

### Rollback Step 3: Verify

```bash
# Check site is working
open http://localhost:8080

# Verify version
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal,version=8.9 -o jsonpath="{.items[0].metadata.name}")
kubectl exec -n drupal $DRUPAL_POD -- cat /var/www/html/core/lib/Drupal.php | grep "const VERSION"
```

---

## Production Considerations

### Downtime
- **Expected:** 10-15 minutes
- **Components affected:** Website (full downtime)
- **Database:** Brief lock during updates

### Pre-Production Checklist
- [ ] Schedule maintenance window
- [ ] Notify stakeholders
- [ ] Enable maintenance mode
- [ ] Verify all backups
- [ ] Test rollback procedure
- [ ] Have team on standby

### Risk Mitigation
- Run upgrade in test environment first (this repo!)
- Have rollback plan ready
- Keep old deployment available during testing
- Monitor logs during upgrade
- Test all critical functionality post-upgrade

### Communication Template

**Before Upgrade:**
```
Subject: Scheduled Maintenance - Drupal Upgrade

We will be performing a major Drupal upgrade from 8.9 to 9.5 on [DATE] at [TIME].

Expected downtime: 15-20 minutes
What's changing: Drupal core version upgrade
Benefits: Security updates, performance improvements

The site will be unavailable during this time.
```

**After Upgrade:**
```
Subject: Maintenance Complete - Drupal Upgrade Successful

The Drupal upgrade from 8.9 to 9.5 has been completed successfully.

The site is now back online and fully operational.
All functionality has been tested and verified.

Thank you for your patience.
```

---

## Troubleshooting

### Issue: Pod Stuck in ImagePullBackOff

**Solution:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n drupal

# Verify image exists
docker pull drupal:9.5-php8.0-apache
```

### Issue: Database Update Fails

**Solution:**
```bash
# Check Drupal logs
kubectl logs -n drupal <drupal-pod> --tail=100

# Access pod and check database connection
kubectl exec -it <drupal-pod> -n drupal -- bash
```

### Issue: Site Shows Errors After Upgrade

**Solution:**
```bash
# Clear all caches
kubectl exec -n drupal <drupal-pod> -- rm -rf /var/www/html/sites/default/files/php/*

# Restart pod
kubectl delete pod <drupal-pod> -n drupal
```

---

## Notes

### Actual Issues Encountered
- **settings.php not persisted**: Drupal containers don't persist settings.php between pod restarts. Solution: Recreate settings.php in new pods after deployment.
- **PHP 8.0 warning**: Initial deployment used PHP 8.0 which showed security warnings. Upgraded to PHP 8.1 (drupal:9.5-php8.1-apache).
- **Twig template errors**: Site showed 500 errors before running database updates. This is expected - database updates must be run before site is functional.
- **Config sync directory required**: Drupal 9 requires explicit config_sync_directory setting in settings.php.
- **Port-forward interruption**: Port-forward needs to be restarted after pod changes.

### Time Tracking
- Pre-upgrade backup: 2 minutes
- Manifest updates: 2 minutes
- Deployment and image pull: 5 minutes
- Database updates: 3 minutes
- Verification: 3 minutes
- Post-upgrade backup: 2 minutes
- **Total:** ~17 minutes

### Resource Usage
- CPU: < 500m during upgrade
- Memory: < 512Mi during upgrade
- Disk: Minimal increase (core files only)
- Network: ~200MB for image download

### Recommendations for Production
1. Test upgrade in this environment first
2. Schedule during low-traffic period
3. Have rollback plan tested and ready
4. Keep old deployment scaled to 0 but available for 24 hours
5. Monitor logs closely during first hour post-upgrade
6. Run full regression test suite after upgrade

---

## Success Criteria

- [ ] Drupal 9.5.x version confirmed
- [ ] Site accessible and functioning
- [ ] Admin login works
- [ ] Content visible and accessible
- [ ] No critical errors in status report
- [ ] Database backup created
- [ ] Changes committed to git
- [ ] Tag created

---

**Upgrade completed:** December 23, 2024 01:54 UTC  
**Performed by:** AI Agent + Human verification  
**Duration:** ~22 minutes (including troubleshooting)  
**Issues:** Settings.php not persisted, required PHP version update to 8.1, manual settings recreation
