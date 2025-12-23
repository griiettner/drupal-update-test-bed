-- Enable pg_trgm extension for Drupal 10
-- This extension is required by Drupal 10 for improved performance with PostgreSQL
-- Run this BEFORE upgrading to Drupal 10

-- Create the pg_trgm extension if it doesn't exist
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Verify the extension is installed
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_trgm';
