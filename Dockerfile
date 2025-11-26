# ─────────────────────────────────────────────────────────────────────────────
# Estágio 1: Builder (Alpine 3.20)
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:3.20 AS builder

ENV MOSQUITTO_VERSION=2.0.22
ENV PATH="/root/.cargo/bin:${PATH}"

# 1. Instalar dependências (Usando OPENSSL-DEV em vez de libressl)
# build-base: compiladores
# openssl-dev: bibliotecas SSL padrão do Alpine 3.20
# c-ares-dev, libwebsockets-dev, cjson-dev: dependências do mosquitto
# linux-headers: necessário para algumas compilações
RUN apk add --no-cache \
    build-base \
    openssl-dev \
    c-ares-dev \
    libwebsockets-dev \
    cjson-dev \
    util-linux-dev \
    linux-headers \
    wget \
    git \
    curl \
    pkgconfig \
    musl-dev

# 2. Instalar Rust via rustup (Versão > 1.82 para o plugin)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rustup target add x86_64-unknown-linux-musl

# 3. Compilar Mosquitto (Linkando contra OpenSSL)
WORKDIR /tmp
RUN wget https://mosquitto.org/files/source/mosquitto-${MOSQUITTO_VERSION}.tar.gz \
    && tar -xzf mosquitto-${MOSQUITTO_VERSION}.tar.gz \
    && cd mosquitto-${MOSQUITTO_VERSION} \
    # Compilação padrão. O Mosquitto detectará o OpenSSL automaticamente.
    && LDFLAGS="-L/usr/lib" make WITH_WEBSOCKETS=yes WITH_SRV=yes WITH_TLS=yes \
    && make install

# 4. Compilar o plugin mosquitto-jwt-auth
WORKDIR /tmp
RUN git clone https://github.com/wiomoc/mosquitto-jwt-auth.git \
    && cd mosquitto-jwt-auth \
    # Compilação para musl mantendo linkagem dinâmica (-crt-static negado) para gerar .so
    && RUSTFLAGS="-C target-feature=-crt-static" cargo build --release --target x86_64-unknown-linux-musl

# ─────────────────────────────────────────────────────────────────────────────
# Estágio 2: Imagem Final (Alpine 3.20)
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:3.20

# 1. Instalar dependências de runtime (OPENSSL em vez de libressl)
RUN apk add --no-cache \
    openssl \
    c-ares \
    libwebsockets \
    cjson \
    libuuid \
    libgcc

# 2. Configurar usuário
RUN addgroup -S mosquitto && adduser -S -H -G mosquitto mosquitto

RUN mkdir -p /mosquitto/config \
    && mkdir -p /mosquitto/data \
    && mkdir -p /mosquitto/log \
    && mkdir -p /mosquitto/plugins \
    && mkdir -p /mosquitto/run

# 3. Copiar binários do Mosquitto
COPY --from=builder /usr/local/sbin/mosquitto /usr/local/sbin/mosquitto
COPY --from=builder /usr/local/lib/libmosquitto.so.1 /usr/local/lib/libmosquitto.so.1

# 4. Copiar o plugin compilado
COPY --from=builder /tmp/mosquitto-jwt-auth/target/x86_64-unknown-linux-musl/release/libmosquitto_jwt_auth.so /mosquitto/plugins/

# 5. Copiar arquivos locais
COPY mosquitto.conf /mosquitto/config/mosquitto.conf
COPY entrypoint.sh /entrypoint.sh

# 6. Permissões
RUN chown -R mosquitto:mosquitto /mosquitto \
    && chmod 644 /mosquitto/config/* \
    && chmod 755 /mosquitto/plugins/libmosquitto_jwt_auth.so \
    && chmod 755 /mosquitto/run \
    && chmod +x /entrypoint.sh

USER mosquitto

EXPOSE 1883 9001

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]