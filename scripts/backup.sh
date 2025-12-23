#!/bin/bash
# Backup script for Drupal database and files

set -e

# Configuration
NAMESPACE="drupal"
BACKUP_DIR="/Users/griiettner/Projects/PWC/drupal_update/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")
DRUPAL_POD=$(kubectl get pod -n $NAMESPACE -l app=drupal -o jsonpath="{.items[0].metadata.name}")

echo "========================================="
echo "Drupal Backup Script"
echo "========================================="
echo "Timestamp: $TIMESTAMP"
echo "PostgreSQL Pod: $POSTGRES_POD"
echo "Drupal Pod: $DRUPAL_POD"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup database
echo "[1/2] Backing up PostgreSQL database..."
kubectl exec -n $NAMESPACE $POSTGRES_POD -- pg_dump -U drupal drupal > "$BACKUP_DIR/drupal_db_$TIMESTAMP.sql"
echo "✓ Database backed up to: drupal_db_$TIMESTAMP.sql"

# Backup Drupal configuration (if Drush is available)
echo "[2/2] Attempting to export Drupal configuration..."
if kubectl exec -n $NAMESPACE $DRUPAL_POD -- which drush > /dev/null 2>&1; then
    kubectl exec -n $NAMESPACE $DRUPAL_POD -- drush config:export -y || echo "⚠ Config export skipped (Drupal may not be installed yet)"
    echo "✓ Configuration export attempted"
else
    echo "⚠ Drush not available, skipping config export"
fi

echo ""
echo "========================================="
echo "Backup completed successfully!"
echo "========================================="
echo "Location: $BACKUP_DIR"
echo "Files:"
echo "  - drupal_db_$TIMESTAMP.sql"
echo ""
