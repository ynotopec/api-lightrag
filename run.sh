#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
VENV_DIR="${VENV_DIR:-$HOME/venv/$PROJECT_NAME}"

IP="${1:-${HOST:-0.0.0.0}}"
PORT_ARG="${2:-${PORT:-9621}}"

cd "$PROJECT_DIR"

if [[ ! -d "$VENV_DIR" ]]; then
  echo "ERROR: venv not found: $VENV_DIR"
  echo "Run: ./install.sh"
  return 1 2>/dev/null || exit 1
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

if [[ ! -f ".env" ]]; then
  if [[ -f ".env.example" ]]; then
    cp .env.example .env
    chmod 600 .env
    echo "Created .env from .env.example"
  else
    echo "ERROR: .env missing"
    return 1 2>/dev/null || exit 1
  fi
fi

mkdir -p inputs rag_storage logs

export HOST="$IP"
export PORT="$PORT_ARG"
export INPUT_DIR="${INPUT_DIR:-$PROJECT_DIR/inputs}"
export WORKING_DIR="${WORKING_DIR:-$PROJECT_DIR/rag_storage}"

MODE="${LIGHTRAG_RUN_MODE:-server}"

echo "Starting LightRAG on ${HOST}:${PORT}"
echo "Working dir: $WORKING_DIR"
echo "Input dir  : $INPUT_DIR"

if [[ "$MODE" == "gunicorn" ]]; then
  exec lightrag-gunicorn \
    --workers "${WORKERS:-1}" \
    --host "$HOST" \
    --port "$PORT"
else
  exec lightrag-server \
    --host "$HOST" \
    --port "$PORT" \
    --working-dir "$WORKING_DIR" \
    --input-dir "$INPUT_DIR"
fi
