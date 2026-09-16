# Transcription server

Place a whisper.cpp GGML model (for example `ggml-large-v3-turbo.bin`) in `models/`.
Use the [upstream model instructions](https://github.com/ggml-org/whisper.cpp/tree/master/models)
to obtain it. Models and recordings are not included in this repository or image.

```sh
mkdir -p models
cp .env.example .env
# Edit MODELS_DIR and MODEL_FILE in .env as needed.
podman compose up -d
```

For a local build, set `WHISPER_IMAGE=localhost/whisper-strix-halo:rocm-fedora43` in `.env`.
Podman Compose requires a Compose provider; `docker compose up -d` is also supported.
The default host binding is localhost:8081. The server has no authentication;
use an authenticated reverse proxy if exposing it remotely.

Rootless Podman can instead run directly with host group access:

```sh
podman run --rm --device /dev/kfd --device /dev/dri \
  --group-add keep-groups --security-opt label=disable \
  -p 127.0.0.1:8081:8080 -v "$PWD/models:/models:ro" \
  localhost/whisper-strix-halo:rocm-fedora43 whisper-server \
  -m /models/ggml-large-v3-turbo.bin --host 0.0.0.0 --port 8080 \
  --inference-path /v1/audio/transcriptions --threads 4 --convert --language auto
```

```sh
curl http://localhost:8081/v1/audio/transcriptions \
  -F file=@sample.wav -F response_format=json
```

This configures the URL used by OpenAI-style transcription clients; it does not
promise full OpenAI API compatibility. `--convert` invokes Fedora's ffmpeg-free;
codec availability depends on that package.

