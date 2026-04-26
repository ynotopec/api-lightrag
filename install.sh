#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
VENV_DIR="${VENV_DIR:-$HOME/venv/$PROJECT_NAME}"

# Stable PyPI par défaut.
# Pour installer directement depuis GitHub :
# LIGHTRAG_SPEC='lightrag-hku[api] @ git+https://github.com/HKUDS/LightRAG.git' ./install.sh
LIGHTRAG_SPEC="${LIGHTRAG_SPEC:-lightrag-hku[api]}"

PYTHON_BIN="${PYTHON_BIN:-python3}"
UV_BIN="${UV_BIN:-uv}"

echo "==> Project dir : $PROJECT_DIR"
echo "==> Venv dir    : $VENV_DIR"
echo "==> Package     : $LIGHTRAG_SPEC"

mkdir -p "$PROJECT_DIR/inputs" "$PROJECT_DIR/rag_storage" "$PROJECT_DIR/logs" "$HOME/venv"

if ! command -v "$UV_BIN" >/dev/null 2>&1; then
  echo "==> Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v "$UV_BIN" >/dev/null 2>&1; then
  echo "ERROR: uv not found after install. Add ~/.local/bin to PATH."
  exit 1
fi

if [[ ! -d "$VENV_DIR" ]]; then
  echo "==> Creating venv..."
  "$UV_BIN" venv "$VENV_DIR" --python "$PYTHON_BIN"
else
  echo "==> Reusing existing venv..."
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "==> Upgrading pip toolchain..."
uv pip install --upgrade pip setuptools wheel

echo "==> Installing/upgrading LightRAG..."
uv pip install --upgrade "$LIGHTRAG_SPEC"

echo "==> Checking commands..."
command -v lightrag-server >/dev/null
command -v lightrag-gunicorn >/dev/null || true

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  if [[ -f "$PROJECT_DIR/.env.example" ]]; then
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    chmod 600 "$PROJECT_DIR/.env"
    echo "==> Created .env from .env.example"
  else
    echo "WARNING: .env.example missing; create .env manually."
  fi
else
  echo "==> Existing .env preserved"
fi

cat > "$PROJECT_DIR/lightrag.service.example" <<EOF
[Unit]
Description=LightRAG Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$VENV_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=$VENV_DIR/bin/lightrag-gunicorn --workers \${WORKERS:-1} --host \${HOST:-0.0.0.0} --port \${PORT:-9621}
Restart=always
RestartSec=5
TimeoutStopSec=30
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

echo
echo "OK."
echo "Next:"
echo "  cd $PROJECT_DIR"
echo "  nano .env"
echo "  source ./run.sh 0.0.0.0 9621"
echo
echo "Systemd example:"
echo "  sudo cp $PROJECT_DIR/lightrag.service.example /etc/systemd/system/lightrag.service"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now lightrag"
