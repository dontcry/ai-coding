#!/bin/bash

cd "$(dirname "$0")"

echo "=== Stopping services ==="
docker compose -f docker-compose.prod.yml down

echo "=== Stopped ==="
