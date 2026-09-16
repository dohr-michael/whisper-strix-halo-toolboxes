# GPU validation and benchmarks

No benchmark results have been published yet. Run the same model and audio with
both backends before making performance comparisons.

```sh
mkdir -p benchmark/results
IMAGE_REPOSITORY=localhost/whisper-strix-halo \
  ./scripts/run.sh rocm-fedora43 whisper-cli \
  -m /models/ggml-large-v3-turbo.bin -f /audio/sample.wav -l en -t 4 \
  > benchmark/results/rocm.txt 2>&1
IMAGE_REPOSITORY=localhost/whisper-strix-halo \
  ./scripts/run.sh vulkan-radv whisper-cli \
  -m /models/ggml-large-v3-turbo.bin -f /audio/sample.wav -l en -t 4 \
  > benchmark/results/vulkan.txt 2>&1
```

Record GPU/CPU model, RAM, kernel, firmware, image digest, Whisper revision, model
checksum, audio checksum and duration, language, thread count, concurrent GPU
workloads, warm-up policy and repeat count. Keep raw timing output and confirm the
expected transcription and selected GPU. Report median wall time and real-time
factor (wall seconds / audio seconds) over repeated runs, distinguishing cold and
warm runs. Do not publish recordings or transcripts without permission.

For the built-in compute benchmark:

```sh
./scripts/run.sh rocm-fedora43 whisper-bench -m /models/ggml-large-v3-turbo.bin -t 4
```

Compute timings are not a substitute for end-to-end transcription latency.
