# ---- Build stage ----
FROM ubuntu:22.04 AS build
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  build-essential git ca-certificates curl pkg-config python3 bsdmainutils \
  cmake ninja-build autoconf automake libtool \
  libboost-all-dev libevent-dev libssl-dev libminiupnpc-dev libzmq3-dev \
  libsqlite3-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth=1 https://github.com/hashcoinx/hashcoinx.git .

ARG CMAKE_JOBS=4
ENV CMAKE_BUILD_PARALLEL_LEVEL=${CMAKE_JOBS}

# CMake -> Autotools -> Makefile.unix (fallback)
RUN set -eux; ok=0; \
  if [ -f CMakeLists.txt ]; then \
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release || true; \
    if [ -f build/build.ninja ]; then cmake --build build -j"${CMAKE_JOBS}" && ok=1; fi; \
  fi; \
  if [ "$ok" -ne 1 ] && { [ -f autogen.sh ] || [ -f configure ]; }; then \
    [ -f autogen.sh ] && ./autogen.sh || true; \
    ./configure --without-gui --disable-tests --disable-bench && make -j"$(nproc)" && ok=1; \
  fi; \
  if [ "$ok" -ne 1 ]; then \
    cd src && make -f makefile.unix -j"$(nproc)" USE_UPNP=- && cd .. && ok=1; \
  fi; \
  mkdir -p /out/bin; \
  find build -type f -perm -111 -exec cp -v {} /out/bin/ \; 2>/dev/null || true; \
  find src   -type f -perm -111 -exec cp -v {} /out/bin/ \; 2>/dev/null || true; \
  find .     -maxdepth 1 -type f -perm -111 -exec cp -v {} /out/bin/ \; 2>/dev/null || true; \
  ls -l /out/bin; test "$(ls -A /out/bin)"

# ---- Runtime stage ----
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive HSCX_DATA=/root/.hashcoinx
RUN apt-get update && apt-get install -y \
  curl ca-certificates jq tini \
  libboost-all-dev libevent-2.1-7 libminiupnpc17 libzmq5 libssl3 libsqlite3-0 \
  && rm -rf /var/lib/apt/lists/* && mkdir -p "$HSCX_DATA"
COPY --from=build /out/bin/ /usr/local/bin/
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh /usr/local/bin/* || true
EXPOSE 8333 8332
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/entrypoint.sh"]
