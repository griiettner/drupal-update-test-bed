# Drupal 9.5.11 → 10.3.x Upgrade Guide

**Date:** December 23, 2024  
**Environment:** Kubernetes (Docker Desktop) + PostgreSQL  
**Duration:** ~20 minutes (estimated)

---

## Prerequisites

### Current State
- **Current Version:** Drupal 9.5.11
- **Target Version:** Drupal 10.3.x
- **PHP Version:** 8.1 → 8.2
- **Database:** PostgreSQL 15
- **Deployment:** Kubernetes manifests

### Required Tools
- `kubectl` - Kubernetes CLI
- `helm` - For PostgreSQL management
- Access to the Kubernetes cluster
- Git access for version control

### Pre-Upgrade Checklist
- [x] Drupal 9.5.11 is running and accessible
- [x] Database backup exists (`backups/db/drupal_9.5.11.sql`)
- [x] Git branch created: `drupal-10.3.x`
- [x] Review Drupal 10 breaking changes

---

## Step 1: Uninstall Deprecated Modules (CRITICAL)

**Time:** ~10 minutes
**MUST BE DONE BEFORE UPGRADING**

### 1.1 Identify Deprecated Modules

Drupal 10 removes these core modules:
- **CKEditor** (replaced by CKEditor 5)
- **Color** (functionality moved)
- **Quick Edit** (functionality changed)
- **RDF** (rarely used)

### 1.2 Replace/Uninstall Modules

**Before upgrading, in Drupal 9:**

1. **Access admin interface**: http://your-site/admin/modules/uninstall

2. **Check module usage:**
   - Go to: Administration → Extend → Uninstall
   - Review which deprecated modules are installed

3. **For CKEditor:**
   ```
   - Go to: Configuration → Text formats and editors
   - For each format using CKEditor:
     * Note the configuration
     * CKEditor 5 will be available after upgrade
     * No action needed if you're okay with default CKEditor 5 settings
   ```

4. **For Seven theme** (admin theme):
   ```
   - Go to: Appearance
   - Set admin theme to "Claro" (built into D10)
   - Uninstall Seven theme
   ```

5. **Uninstall deprecated modules:**
   ```
   Via UI:
   - Administration → Extend → Uninstall
   - Check: Color, Quick Edit, RDF, CKEditor (if you can)
   - Click "Uninstall"
   ```

**IMPORTANT**: Some modules can't be uninstalled if they have data. Document these for post-upgrade cleanup.

### 1.3 Verify Uninstallation

```bash
# After uninstalling, verify via Drush (if available)
# In Drupal 9 pod:
drush pm:list --status=enabled --format=table | grep -E "ckeditor|color|quickedit|rdf"
```

**Expected**: No results (modules uninstalled)

---

## Step 2: Enable PostgreSQL pg_trgm Extension

**Time:** ~1 minute
**REQUIRED FOR DRUPAL 10**

### 2.1 Install pg_trgm Extension

Drupal 10 requires the pg_trgm PostgreSQL extension for improved performance.

```bash
# Get PostgreSQL pod
POSTGRES_POD=$(kubectl get pod -n drupal -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")

# Run SQL migration script
kubectl exec -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=postgres123 psql -U postgres -d drupal -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'"
```

**Alternative: Using SQL file**
```bash
# From project root
kubectl exec -i -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=postgres123 psql -U postgres -d drupal" < scripts/sql/enable_pg_trgm.sql
```

### 2.2 Verify Extension

```bash
kubectl exec -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=postgres123 psql -U postgres -d drupal -c 'SELECT extname, extversion FROM pg_extension WHERE extname = \"pg_trgm\";'"
```

**Expected Output:**
```
 extname | extversion
---------+------------
 pg_trgm | 1.6
```

---

## Step 3: Pre-Upgrade Backup

**Time:** ~2 minutes

### 3.1 Create Database Backup

```bash
# Get PostgreSQL pod name
POSTGRES_POD=$(kubectl get pod -n drupal -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")

# Create backup
kubectl exec -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=drupal123 pg_dump -U drupal drupal" > backups/db/drupal_9.5.11_pre-upgrade-to-d10.sql

# Verify backup
ls -lh backups/db/
```

**Expected Output:**
```
-rw-r--r-- 1 user staff 9.7M Dec 23 02:00 drupal_9.5.11_pre-upgrade-to-d10.sql
```

---

## Step 2: Update Kubernetes Manifest

**Time:** ~2 minutes

### 2.1 Verify Current Deployment

```bash
kubectl get deployment drupal-d9 -n drupal -o yaml | grep "image:"
```

**Expected Output:**
```yaml
image: drupal:9.5-php8.1-apache
```

### 2.2 Create New Manifest for Drupal 10

```bash
cp kubernetes/drupal-d9.yaml kubernetes/drupal-d10.yaml
```

Edit the file to change:
- Image: `drupal:9.5-php8.1-apache` → `drupal:10.3-php8.2-apache`
- Deployment name: `drupal-d9` → `drupal-d10`
- Labels: `version: "9.5"` → `version: "10.3"`

**Key changes in manifest:**
```yaml
# Line 41: Update deployment name
name: drupal-d10

# Line 45: Update version label
version: "10.3"

# Line 60: Update image
image: drupal:10.3-php8.2-apache
```

---

## Step 3: Apply Drupal 10 Deployment

**Time:** ~5-8 minutes (including image pull)

### 3.1 Apply New Deployment

```bash
kubectl apply -f kubernetes/drupal-d10.yaml
```

**Expected Output:**
```
persistentvolumeclaim/drupal-files unchanged
configmap/drupal-config unchanged
secret/drupal-secrets unchanged
deployment.apps/drupal-d10 created
service/drupal unchanged
```

### 3.2 Monitor Pod Creation

```bash
kubectl get pods -n drupal -w
```

**Wait for:**
- New `drupal-d10-xxx` pod to show `STATUS: Running` and `READY: 1/1`
- This may take 3-5 minutes for image download

### 3.3 Create settings.php in New Pod

```bash
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal,version=10.3 -o jsonpath="{.items[0].metadata.name}")

kubectl exec -n drupal $DRUPAL_POD -- bash -c "cat > /var/www/html/sites/default/settings.php << 'EOF'
<?php
\$databases['default']['default'] = array (
  'database' => 'drupal',
  'username' => 'drupal',
  'password' => 'drupal123',
  'prefix' => '',
  'host' => 'postgresql.drupal.svc.cluster.local',
  'port' => '5432',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\pgsql',
  'driver' => 'pgsql',
);
\$settings['hash_salt'] = 'temp-salt-$(openssl rand -hex 32)';
\$settings['update_free_access'] = FALSE;
\$settings['container_yamls'][] = __DIR__ . '/services.yml';
\$settings['file_scan_ignore_directories'] = ['node_modules', 'bower_components'];
\$settings['entity_update_batch_size'] = 50;
\$settings['entity_update_backup'] = TRUE;
\$settings['migrate_node_migrate_type_classic'] = FALSE;
\$settings['config_sync_directory'] = 'sites/default/files/sync';
EOF
chmod 644 /var/www/html/sites/default/settings.php
mkdir -p /var/www/html/sites/default/files/sync
chmod 777 /var/www/html/sites/default/files/sync"
```

### 3.4 Scale Down Old Deployment

```bash
kubectl scale deployment drupal-d9 -n drupal --replicas=0
```

**Expected Output:**
```
deployment.apps/drupal-d9 scaled
```

---

## Step 4: Database Updates

**Time:** ~3-5 minutes

### 4.1 Restart Port-Forward

```bash
# Kill old port-forward
pkill -f "port-forward.*drupal"

# Start new port-forward
kubectl port-forward -n drupal svc/drupal 8080:80 &
```

### 4.2 Run Database Updates via Web UI

1. Access: http://localhost:8080/update.php
2. Review pending updates
3. Click "Continue" to run database updates
4. Wait for completion (may take 2-3 minutes)

**Expected Updates:**
- Core module updates
- Schema changes for Drupal 10
- Configuration updates

---

## Step 5: Verification

**Time:** ~3 minutes

### 5.1 Verify Drupal Version

```bash
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal,version=10.3 -o jsonpath="{.items[0].metadata.name}")
kubectl exec -n drupal $DRUPAL_POD -- cat /var/www/html/core/lib/Drupal.php | grep "const VERSION"
```

**Expected Output:**
```php
const VERSION = '10.3.x';
```

### 5.2 Access Web Interface

```bash
# Open browser
open http://localhost:8080
```

**Verify:**
- [ ] Site loads successfully
- [ ] Can log in as admin
- [ ] Status report shows Drupal 10.3.x
- [ ] PHP version 8.2.x
- [ ] No critical errors
- [ ] Content is visible

### 5.3 Check Status Report

1. Go to: http://localhost:8080/admin/reports/status
2. Verify:
   - Drupal version: 10.3.x
   - PHP version: 8.2.x
   - Database: Connected
   - No critical errors

---

## Step 6: Post-Upgrade Steps

**Time:** ~3 minutes

### 6.1 Create Post-Upgrade Backup

```bash
POSTGRES_POD=$(kubectl get pod -n drupal -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")

kubectl exec -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=drupal123 pg_dump -U drupal drupal" > backups/db/drupal_10.3.x.sql

# Verify backup size
ls -lh backups/db/drupal_10.3.x.sql
```

### 6.2 Clean Up Old Deployment

```bash
# Delete old Drupal 9 deployment
kubectl delete deployment drupal-d9 -n drupal

# Verify only Drupal 10 is running
kubectl get deployments -n drupal
```

**Expected Output:**
```
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
drupal-d10   1/1     1            1           15m
```

---

## Step 7: Git Workflow

**Time:** ~2 minutes

### 7.1 Commit Changes

```bash
git add .
git commit -m "Phase 3: Drupal 10.3.x upgrade

- Updated to drupal:10.3-php8.2-apache image
- Created new kubernetes/drupal-d10.yaml manifest
- Ran database updates successfully
- Database backup: backups/db/drupal_10.3.x.sql
- Comprehensive upgrade documentation
- Verified functionality and status"

git push origin drupal-10.3.x
```

### 7.2 Create Pull Request

Create PR via GitHub web interface.

### 7.3 After Merge: Create Tag

```bash
git checkout main
git pull
git tag -a v3.0-drupal-10.3 -m "Drupal 10.3.x upgrade - Working and verified"
git push origin v3.0-drupal-10.3
```

---

## Rollback Procedure

If the upgrade fails:

### Rollback Step 1: Restore Old Deployment

```bash
# Scale up Drupal 9 deployment
kubectl scale deployment drupal-d9 -n drupal --replicas=1

# Scale down Drupal 10 deployment
kubectl scale deployment drupal-d10 -n drupal --replicas=0

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
kubectl exec -i -n drupal $POSTGRES_POD -- bash -c "PGPASSWORD=drupal123 psql -U drupal drupal" < backups/db/drupal_9.5.11.sql
```

---

## Production Considerations

### Downtime
- **Expected:** 10-15 minutes
- **Components affected:** Website (full downtime)
- **Database:** Brief lock during updates

### Key Changes in Drupal 10
- **CKEditor 5**: Major WYSIWYG editor upgrade
- **jQuery updated**: May affect custom JavaScript
- **Deprecated APIs removed**: Review custom code
- **PHP 8.2 required**: Minimum version increased
- **Composer 2**: Required for dependency management

### Pre-Production Checklist
- [ ] Review all custom modules for Drupal 10 compatibility
- [ ] Test custom themes with Drupal 10
- [ ] Check contrib module versions support D10
- [ ] Review CKEditor configuration
- [ ] Test all forms and WYSIWYG fields
- [ ] Schedule maintenance window
- [ ] Notify stakeholders
- [ ] Have rollback plan tested

---

## Troubleshooting

### Issue: CKEditor Configuration Issues

**Solution:**
```bash
# Clear configuration cache
kubectl exec -n drupal <drupal-pod> -- rm -rf /var/www/html/sites/default/files/php/*

# Rebuild cache
kubectl delete pod <drupal-pod> -n drupal
```

### Issue: Module Compatibility Warnings

**Solution:**
- Review each module's Drupal 10 compatibility
- Update modules to D10-compatible versions
- Disable incompatible modules before upgrade

### Issue: Custom Code Deprecation Warnings

**Solution:**
- Review Drupal 10 change log
- Update custom code to use new APIs
- Test thoroughly in development environment

---

## Notes

### Actual Issues Encountered
- **Deprecated modules blocking upgrade**: CKEditor, Color, Quick Edit, RDF, Seven theme must be uninstalled from Drupal 9 BEFORE upgrading to Drupal 10
- **settings.php not persisted**: Had to recreate settings.php in each new pod after deployment
- **CSS/JS 404 errors**: Cached assets failed to load initially. Used `?continue=1` parameter to bypass and proceed with updates
- **pg_trgm extension required**: PostgreSQL pg_trgm extension must be installed before upgrade
- **Pod switching workflow**: Had to switch back to D9, uninstall modules, backup, then switch to D10

### Time Tracking
- Module uninstallation (D9): 5 minutes
- Pre-upgrade backup: 2 minutes
- PostgreSQL extension install: 1 minute
- Manifest updates: 2 minutes
- Deployment and image pull: 2 minutes
- Database updates: 3 minutes
- Verification: 2 minutes
- Post-upgrade backup: 2 minutes
- **Total:** ~19 minutes (plus troubleshooting)

### Resource Usage
- CPU: < 500m during upgrade
- Memory: < 512Mi during upgrade
- Disk: Minimal increase
- Network: ~250MB for image download

### Recommendations for Production
1. Test Drupal 10 compatibility of all custom modules first
2. Review CKEditor 5 changes with content team
3. Test all user workflows post-upgrade
4. Monitor performance closely
5. Keep Drupal 9 deployment available for 48 hours

---

## Success Criteria

- [ ] Drupal 10.3.x version confirmed
- [ ] Site accessible and functioning
- [ ] Admin login works
- [ ] Content visible and accessible
- [ ] CKEditor working properly
- [ ] No critical errors in status report
- [ ] Database backup created
- [ ] Changes committed to git
- [ ] Tag created

---

**Upgrade completed:** December 23, 2024 02:34 UTC  
**Performed by:** AI Agent + Human verification  
**Duration:** ~19 minutes (including module uninstallation)  
**Issues:** Deprecated modules required uninstallation, pg_trgm extension needed, CSS/JS cache issues resolved with ?continue=1
