#!/bin/sh
set -e

liquibase \
  --search-path=/liquibase/changelog \
  --changelog-file=changelog.xml \
  rollback-count --count=1