#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Vault Test Suite"
echo "=========================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
  echo "⚠️  Docker not found. Tests require CouchDB 3.0+"
  echo ""
  echo "Option 1: Install Docker and run tests:"
  echo "  - Install Docker Desktop from https://www.docker.com"
  echo "  - Then run: make test"
  echo ""
  echo "Option 2: Start CouchDB manually:"
  echo "  - Install CouchDB 3.0+ locally"
  echo "  - Start CouchDB on http://localhost:5984"
  echo "  - Then run: mix compile && rebar3 ct"
  exit 1
fi

# Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker daemon is not running. Start Docker Desktop and try again."
  exit 1
fi

# Start CouchDB
echo "Starting CouchDB..."
docker-compose up -d couchdb

# Wait for CouchDB to be ready
echo "Waiting for CouchDB to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:5984/ > /dev/null 2>&1; then
    echo "✅ CouchDB is ready"
    break
  fi
  echo "  Attempt $i/30: waiting for CouchDB..."
  sleep 1
done

# Check if CouchDB is running
if ! curl -s http://localhost:5984/ > /dev/null 2>&1; then
  echo "❌ CouchDB failed to start."
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check Docker logs: docker logs $(docker ps -a -q -f ancestor=couchdb:3.3 2>/dev/null | head -1)"
  echo "  2. Ensure port 5984 is not in use: lsof -i :5984"
  echo "  3. Try again: make test"
  exit 1
fi

echo ""
echo "Compiling Erlang source files..."
mix compile

echo ""
echo "Running Common Test suites..."
export ERL_LIBS="_build/test/lib"

rebar3 ct "$@"

TEST_RESULT=$?

echo ""
echo "=========================================="
if [ $TEST_RESULT -eq 0 ]; then
  echo "✅ All tests passed!"
else
  echo "⚠️  Some tests failed (this may be expected if CouchDB is still starting)"
fi
echo "=========================================="
echo ""
echo "Test logs: _build/test/logs/index.html"
echo ""
echo "CouchDB is still running."
echo "To stop it, run: docker-compose down"
echo "To view logs: docker-compose logs -f couchdb"
echo ""

exit $TEST_RESULT
