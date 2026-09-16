FROM registry.fedoraproject.org/fedora:43 AS build
ARG WHISPER_REF=02612981545f58188a44de99b8a4710793714629
ARG BUILD_JOBS=4
RUN dnf -y --nodocs --setopt=install_weak_deps=False install \
    git cmake ninja-build gcc-c++ rocm-hip-devel hipblas-devel rocblas-devel \
    && dnf clean all
WORKDIR /src
RUN git init whisper.cpp && cd whisper.cpp \
    && git remote add origin https://github.com/ggml-org/whisper.cpp.git \
    && git fetch --depth=1 origin "${WHISPER_REF}" \
    && git checkout --detach FETCH_HEAD \
    && git rev-parse HEAD > /src/whisper-revision.txt
RUN cmake -S whisper.cpp -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_HIP_COMPILER=/usr/lib64/rocm/llvm/bin/clang++ \
    -DCMAKE_HIP_ARCHITECTURES=gfx1151 \
    -DGGML_HIP=ON -DGGML_HIP_NO_VMM=ON -DGGML_NATIVE=OFF \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=ON \
    && cmake --build build --parallel "${BUILD_JOBS}" \
        --target whisper-server whisper-cli whisper-bench whisper-quantize

FROM registry.fedoraproject.org/fedora:43
RUN dnf -y --nodocs --setopt=install_weak_deps=False install \
    rocm-hip rocblas hipblas ffmpeg-free libgomp ca-certificates \
    && dnf clean all && rm -rf /var/cache/dnf/*
COPY --from=build /src/build/bin/ /opt/whisper/bin/
COPY --from=build /src/whisper.cpp/LICENSE /usr/share/licenses/whisper.cpp/LICENSE
COPY --from=build /src/whisper-revision.txt /opt/whisper/whisper-revision.txt
ENV PATH="/opt/whisper/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/whisper/bin"
WORKDIR /opt/whisper
EXPOSE 8080
ENTRYPOINT ["whisper-server"]
CMD ["--help"]
