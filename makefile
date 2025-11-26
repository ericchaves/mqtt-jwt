# Makefile
.PHONY: all clean keys_dir hs_keys es_keys rs_keys ps_keys

# Definir o shell como BASH para garantir a sintaxe avançada (arrays, loops)
SHELL := /bin/bash

# Diretório onde as chaves serão salvas
KEYS_DIR = keys

# Algoritmos Simétricos (HSxxx) - Apenas chave secreta (secret.key)
HS_ALGOS = 256 384 512

# Algoritmos de Curva Elíptica (ESxxx) - Requer chave privada e pública
ES_ALGOS = 256 384 512
ES_CURVES = prime256v1 secp384r1 secp521r1 # Curvas OpenSSL equivalentes (521 é o padrão para ES512)

# Algoritmos RSA (RSxxx) - Requer chave privada e pública
RS_ALGOS = 256 384 512
RS_KEY_SIZE = 2048

# Algoritmos RSA-PSS (PSxxx) - Requer chave privada e pública (mesma lógica do RSxxx)
PS_ALGOS = 256 384 512

# ----------------------------------------------------------------------
# COMANDOS PRINCIPAIS
# ----------------------------------------------------------------------

all: $(KEYS_DIR) hs_keys es_keys rs_keys ps_keys
	@echo ""
	@echo "✅ Todas as chaves JWT foram geradas com sucesso na pasta '$(KEYS_DIR)/'."

# Comando para limpar todos os arquivos de chave gerados
clean:
	@echo "🗑️ Limpando diretório de chaves..."
	rm -rf $(KEYS_DIR)

# ----------------------------------------------------------------------
# DIRETÓRIO
# ----------------------------------------------------------------------

$(KEYS_DIR):
	@echo "📁 Criando diretório '$(KEYS_DIR)/'..."
	mkdir -p $(KEYS_DIR)

# ----------------------------------------------------------------------
# 1. CHAVES SIMÉTRICAS (HS256, HS384, HS512)
# ----------------------------------------------------------------------

hs_keys: $(KEYS_DIR)
	@echo "🔐 Gerando chaves simétricas (HSxxx)..."
	@for algo in $(HS_ALGOS); do \
		echo "  -> Gerando chave para HS$$algo"; \
		openssl rand -base64 64 > $(KEYS_DIR)/HS$$algo.secret.key; \
	done
	@echo "   (Chaves secretas salvas como HSxxx.secret.key)"

# ----------------------------------------------------------------------
# 2. CHAVES DE CURVA ELÍPTICA (ES256, ES384, ES512) - CORRIGIDO
# ----------------------------------------------------------------------

# Transforma as listas em arrays bash e itera sobre os índices
es_keys: $(KEYS_DIR)
	@echo "🔐 Gerando chaves de curva elíptica (ESxxx)..."
	@ALGOS=($(ES_ALGOS)); \
	CURVES=($(ES_CURVES)); \
	for i in $$(seq 0 $${#ALGOS[@]}); do \
		algo=$${ALGOS[$$i]}; \
		curve=$${CURVES[$$i]}; \
		if [ -z "$$curve" ]; then continue; fi; \
		echo "  -> Gerando par de chaves para ES$$algo (Curva $$curve)"; \
		openssl ecparam -name $$curve -genkey -noout -out $(KEYS_DIR)/ES$$algo.private.pem; \
		openssl ec -in $(KEYS_DIR)/ES$$algo.private.pem -pubout -out $(KEYS_DIR)/ES$$algo.public.pem; \
	done
	@echo "   (Chaves salvas como ESxxx.private.pem e ESxxx.public.pem)"

# ----------------------------------------------------------------------
# 3. CHAVES RSA (RS256, RS384, RS512)
# ----------------------------------------------------------------------

rs_keys: $(KEYS_DIR)
	@echo "🔐 Gerando chaves RSA (RSxxx)..."
	@for algo in $(RS_ALGOS); do \
		echo "  -> Gerando par de chaves para RS$$algo (Tamanho $(RS_KEY_SIZE))"; \
		openssl genrsa -out $(KEYS_DIR)/RS$$algo.private.pem $(RS_KEY_SIZE); \
		openssl rsa -in $(KEYS_DIR)/RS$$algo.private.pem -pubout -out $(KEYS_DIR)/RS$$algo.public.pem; \
	done
	@echo "   (Chaves salvas como RSxxx.private.pem e RSxxx.public.pem)"

# ----------------------------------------------------------------------
# 4. CHAVES RSA-PSS (PS256, PS384, PS512)
# ----------------------------------------------------------------------

ps_keys: rs_keys
	@echo "🔐 As chaves RSA geradas (RSxxx) também são válidas para RSA-PSS (PSxxx)."
	@echo "   (Usam o mesmo par de chaves, apenas a assinatura/verificação muda.)"
	@echo "   (Nenhuma chave nova gerada, utilize os arquivos RSxxx.pem)."