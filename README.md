# LightRAG local install

Installation idempotente de LightRAG avec `uv`, venv externe dans `~/venv/<project-dir>`, API token, et support systemd.

## Layout

```bash
~/lightrag
├── install.sh
├── run.sh
├── .env
├── .env.example
├── inputs/
├── rag_storage/
└── logs/
```

## Install / upgrade

```bash
cd ~/lightrag
./install.sh
```

Upgrade plus tard :

```bash
cd ~/lightrag
./install.sh
```

Installer depuis GitHub main :

```bash
cd ~/lightrag
LIGHTRAG_SPEC='lightrag-hku[api] @ git+https://github.com/HKUDS/LightRAG.git' ./install.sh
```

## Configure

```bash
cp .env.example .env
nano .env
```

À modifier en priorité :

```bash
LIGHTRAG_API_KEY=...
LLM_BINDING_HOST=...
LLM_BINDING_API_KEY=...
LLM_MODEL=...
EMBEDDING_BINDING_HOST=...
EMBEDDING_BINDING_API_KEY=...
EMBEDDING_MODEL=...
EMBEDDING_DIM=...
```

Pour `BAAI/bge-multilingual-gemma2` (endpoint OpenAI-compatible), utiliser en général :

```bash
EMBEDDING_MODEL=BAAI/bge-multilingual-gemma2
EMBEDDING_DIM=3584
EMBEDDING_TOKEN_LIMIT=8192
```

Puis vérifier la cohérence :

- `EMBEDDING_BINDING=openai`
- `EMBEDDING_BINDING_HOST` pointe bien vers le serveur d'embeddings (pas le serveur LLM)
- `EMBEDDING_DIM` correspond à la dimension réellement renvoyée par le backend

## Run

```bash
source ./run.sh 0.0.0.0 9621
```

Mode gunicorn :

```bash
LIGHTRAG_RUN_MODE=gunicorn WORKERS=2 source ./run.sh 0.0.0.0 9621
```

## Health

```bash
curl http://127.0.0.1:9621/health
```

## API token

LightRAG utilise le header :

```bash
X-API-Key: <token>
```

Exemple :

```bash
curl -X POST 'http://127.0.0.1:9621/documents/scan' \
  -H 'accept: application/json' \
  -H "X-API-Key: ${LIGHTRAG_API_KEY}" \
  -d ''
```

## Systemd

```bash
sudo cp ~/lightrag/lightrag.service.example /etc/systemd/system/lightrag.service
sudo systemctl daemon-reload
sudo systemctl enable --now lightrag
sudo systemctl status lightrag
```

Logs :

```bash
journalctl -u lightrag -f
```

Restart :

```bash
sudo systemctl restart lightrag
```

## Open WebUI

LightRAG expose une interface compatible Ollama avec le modèle `lightrag:latest`.

Dans Open WebUI, ajouter une connexion Ollama vers :

```text
http://<host>:9621
```

## Reverse proxy NGINX

Si upload de gros fichiers :

```nginx
client_max_body_size 200M;
```

LightRAG recommande cette configuration pour éviter les erreurs `413 Request Entity Too Large` sur `/documents/upload`.

## H100 / DGX Spark

LightRAG ne charge pas lui-même le gros LLM en GPU si tu utilises un backend OpenAI-compatible externe.

Architecture recommandée :

```text
LightRAG CPU/RAM
  -> LLM backend vLLM/SGLang/Ollama sur H100 ou DGX Spark
  -> embedding backend séparé
  -> optionnel reranker backend séparé
```

Sur H100/DGX Spark, garde LightRAG sobre :

```bash
MAX_ASYNC=4
MAX_PARALLEL_INSERT=2
EMBEDDING_FUNC_MAX_ASYNC=8
EMBEDDING_BATCH_NUM=10
```

Puis augmente seulement si ton backend LLM tient la concurrence.

## Reranking et parallélisme

Dans ce template, il n’y a **pas** de variable dédiée du type `RERANK_MAX_ASYNC`.

Le reranking suit donc la concurrence globale côté requêtes, pilotée surtout par :

```bash
MAX_ASYNC=4
```

Si tu observes “4 en parallèle”, c’est généralement cette limite qui s’applique.

En pratique :

- augmente `MAX_ASYNC` pour autoriser plus de requêtes simultanées (et donc potentiellement plus de rerank en vol) ;
- vérifie que ton backend de rerank (Cohere, FastAPI custom, etc.) supporte la charge ;
- garde un œil sur latence/timeouts avant de monter trop haut.

## Reset index

Attention : supprime l’index local.

```bash
systemctl stop lightrag || true
rm -rf rag_storage/*
rm -rf inputs/*
```

Redémarrer ensuite :

```bash
source ./run.sh 0.0.0.0 9621
```
