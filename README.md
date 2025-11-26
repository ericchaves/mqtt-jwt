# Mosquitto JWT Server

Servidor MQTT Mosquitto com autenticação JWT integrada.

## Características

- **Mosquitto 2.0.22** - Broker MQTT 2.0
- **Autenticação JWT** - Plugin [mosquitto-jwt-auth](https://github.com/wiomoc/mosquitto-jwt-auth) para autenticação baseada em tokens
- **Multi-algoritmo** - Suporte para HS256, HS384, HS512, ES256, ES384, ES512, RS256, RS384, RS512
- **WebSockets** - Suporte a conexões MQTT sobre WebSockets (porta 9001)
- **Docker Ready** - Imagens otimizadas com multi-stage build
- **Alta Performance** - Configurado para até 65536 conexões simultâneas
- **CI/CD** - Pipeline GitHub Actions para publicação automática no GHCR

## Requisitos

- Docker e Docker Compose
- Make (para geração de chaves JWT)
- OpenSSL (para geração de chaves)

## Início Rápido

### 1. Gerar Chaves JWT

O projeto inclui um Makefile para facilitar a geração de chaves para diferentes algoritmos JWT:

```bash
# Gerar todas as chaves (HS, ES, RS)
make all

# Gerar apenas chaves simétricas (HS256, HS384, HS512)
make hs_keys

# Gerar apenas chaves de curva elíptica (ES256, ES384, ES512)
make es_keys

# Gerar apenas chaves RSA (RS256, RS384, RS512)
make rs_keys

# Limpar todas as chaves geradas
make clean
```

As chaves serão criadas no diretório `keys/`:

```
keys/
├── HS256.secret.key      # Chave secreta para HS256
├── HS384.secret.key      # Chave secreta para HS384
├── HS512.secret.key      # Chave secreta para HS512
├── ES256.private.pem     # Chave privada ES256
├── ES256.public.pem      # Chave pública ES256
├── ES384.private.pem     # Chave privada ES384
├── ES384.public.pem      # Chave pública ES384
├── ES512.private.pem     # Chave privada ES512
├── ES512.public.pem      # Chave pública ES512
├── RS256.private.pem     # Chave privada RS256
├── RS256.public.pem      # Chave pública RS256
├── RS384.private.pem     # Chave privada RS384
├── RS384.public.pem      # Chave pública RS384
├── RS512.private.pem     # Chave privada RS512
└── RS512.public.pem      # Chave pública RS512
```

### 2. Executar com Docker Compose

```bash
# Construir e iniciar o serviço
docker compose up -d

# Ver logs
docker compose logs -f

# Parar o serviço
docker compose down
```

### 3. Testar Conexão

```bash
# Primeiro, gere um token JWT válido com a chave correspondente
# Exemplo com HS256:
# (Instale jwt-cli: cargo install jwt-cli)

# Conectar ao broker
mosquitto_pub -h localhost -p 1883 -t test/topic -m "Hello MQTT" -u username -P "seu_token_jwt_aqui"
```

## Configuração

### Mosquitto (mosquitto.conf)

O arquivo [mosquitto.conf](mosquitto.conf) contém as configurações principais:

```conf
# Listeners
listener 1883 0.0.0.0    # MQTT padrão
listener 9001 0.0.0.0    # WebSockets
protocol websockets

# Segurança
allow_anonymous false    # Requer autenticação

# Limites de Conexão
max_connections 65536
max_inflight_messages 50
max_queued_messages 1024

# Plugin JWT
auth_plugin /mosquitto/plugins/libmosquitto_jwt_auth.so
auth_opt_jwt_alg HS256
auth_opt_jwt_sec_file /mosquitto/config/jwt_secret.key
auth_opt_jwt_validate_exp false
auth_opt_jwt_validate_sub_match_username false
```

### Algoritmos JWT Suportados

Para usar um algoritmo diferente, edite o [mosquitto.conf](mosquitto.conf) e monte a chave correspondente:

**Algoritmos Simétricos (HMAC):**
- `HS256` - HMAC com SHA-256 (padrão)
- `HS384` - HMAC com SHA-384
- `HS512` - HMAC com SHA-512

**Algoritmos de Curva Elíptica:**
- `ES256` - ECDSA com P-256 e SHA-256
- `ES384` - ECDSA com P-384 e SHA-384
- `ES512` - ECDSA com P-521 e SHA-512

**Algoritmos RSA:**
- `RS256` - RSA com SHA-256
- `RS384` - RSA com SHA-384
- `RS512` - RSA com SHA-512

**Exemplo de configuração para ES256:**

```yaml
# compose.yml
volumes:
  - ./keys/ES256.public.pem:/mosquitto/config/jwt_secret.key:ro
```

```conf
# mosquitto.conf
auth_opt_jwt_alg ES256
auth_opt_jwt_sec_file /mosquitto/config/jwt_secret.key
```

### Docker Compose (compose.yml)

O arquivo [compose.yml](compose.yml) define o serviço:

```yaml
services:
  mqtt:
    image: mqtt-jwt:local
    ports:
      - "1883:1883"  # MQTT
      - "9001:9001"  # WebSockets
    volumes:
      - mosquitto_data:/mosquitto/data
      - ./mosquitto.conf:/mosquitto/config/mosquitto.conf
      - ./keys/HS256.secret.key:/mosquitto/config/jwt_secret.key:ro
```

### Usar Imagem do GHCR

```bash
docker pull ghcr.io/ericchaves/mosquitto-jwt-server:latest
```

## Gerando Tokens JWT

### Exemplo com Node.js (jsonwebtoken)

```javascript
const jwt = require('jsonwebtoken');
const fs = require('fs');

// Carregar chave secreta
const secret = fs.readFileSync('keys/HS256.secret.key', 'utf8').trim();

// Criar payload
const payload = {
  sub: 'username',
  exp: Math.floor(Date.now() / 1000) + 3600  // Expira em 1 hora
};

// Gerar token
const token = jwt.sign(payload, secret, { algorithm: 'HS256' });
console.log(token);
```

## Segurança

### Boas Práticas

1. **Nunca commitar chaves** - O diretório `keys/` está no `.gitignore`
2. **Usar HTTPS/TLS** - Para produção, habilite TLS no Mosquitto
3. **Rotação de chaves** - Regenere chaves periodicamente
4. **Validar expiração** - Configure `auth_opt_jwt_validate_exp true` em produção
5. **Limitar permissões** - Use claims JWT para controlar ACL de tópicos

### Habilitar TLS

Edite [mosquitto.conf](mosquitto.conf):

```conf
listener 8883 0.0.0.0
cafile /mosquitto/certs/ca.crt
certfile /mosquitto/certs/server.crt
keyfile /mosquitto/certs/server.key
```

## Troubleshooting

### Plugin não carrega

```bash
# Verificar se o plugin existe
docker exec mqtt-container ls -la /mosquitto/plugins/

# Verificar logs
docker compose logs mqtt
```

### Erro de autenticação

```bash
# Verificar se a chave está montada corretamente
docker exec mqtt-container cat /mosquitto/config/jwt_secret.key

# Testar token
jwt decode SEU_TOKEN
```

### Conexão recusada

```bash
# Verificar se as portas estão abertas
netstat -tuln | grep -E '1883|9001'

# Testar conectividade
telnet localhost 1883
```

## Referências

- [Mosquitto MQTT Broker](https://mosquitto.org/)
- [mosquitto-jwt-auth Plugin](https://github.com/wiomoc/mosquitto-jwt-auth)
- [JWT.io](https://jwt.io/) - Decodificar e testar tokens
- [MQTT.org](https://mqtt.org/) - Protocolo MQTT