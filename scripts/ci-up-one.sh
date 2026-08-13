#!/bin/sh
set -e

liquibase \
  --search-path=/liquibase/changelog \
  --changelog-file=changelog.xml \
  update-count --count=1