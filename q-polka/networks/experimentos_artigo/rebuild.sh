#!/bin/bash
make clean -C targets/simple_switch
# Definição de cores e estilos para um visual "pro"
GREEN='\033[0;32m'
BOLD='\033[1m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor (Reset)

# Função para mensagens de progresso
info() {
    echo -e "${BLUE}${BOLD}==>${NC} ${BOLD}$1${NC}"
}

# 1. Verificação de bibliotecas core (prevenção pós-clean)
if [ ! -f "src/bm_sim/.libs/libbmsim.a" ]; then
    info "Bibliotecas core ausentes. Iniciando compilação do diretório src/..."
    make -C src -j$(( $(nproc) - 1 ))
fi

# 2. Compilação do target
info "Compilando simple_switch (reservando 1 núcleo)..."

make clean -C targets/simple_switch

if make -C targets/simple_switch -j$(( $(nproc) - 1 )); then
    
    info "Instalando binários e atualizando links..."
    sudo make -C targets/simple_switch install
    sudo ldconfig
    
    # --- BANNER DE SUCESSO ELEGANTE ---
    echo -e "\n${GREEN}${BOLD}┌────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}${BOLD}│                                                    │${NC}"
    echo -e "${GREEN}${BOLD}│   ✔  COMPILAÇÃO E INSTALAÇÃO CONCLUÍDAS COM ÊXITO  │${NC}"
    echo -e "${GREEN}${BOLD}│                                                    │${NC}"
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}\n"
    
else
    # Mensagem de erro caso a compilação falhe
    echo -e "\n${RED}${BOLD} [!] ERRO CRÍTICO:${NC} A compilação falhou."
    echo -e " Verifique as mensagens de erro acima para diagnosticar o problema.\n"
    exit 1
fi


# 3. Compilação do target
info "Compilando simple_switch (reservando 1 núcleo)..."

make clean -C targets/simple_switch_grpc

if make -C targets/simple_switch_grpc -j$(( $(nproc) - 1 )); then
    
    info "Instalando binários e atualizando links..."
    sudo make -C targets/simple_switch_grpc install
    sudo ldconfig
    
    # --- BANNER DE SUCESSO ELEGANTE ---
    echo -e "\n${GREEN}${BOLD}┌────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}${BOLD}│                                                    │${NC}"
    echo -e "${GREEN}${BOLD}│   ✔  COMPILAÇÃO E INSTALAÇÃO CONCLUÍDAS COM ÊXITO  │${NC}"
    echo -e "${GREEN}${BOLD}│                                                    │${NC}"
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}\n"
    
else
    # Mensagem de erro caso a compilação falhe
    echo -e "\n${RED}${BOLD} [!] ERRO CRÍTICO:${NC} A compilação falhou."
    echo -e " Verifique as mensagens de erro acima para diagnosticar o problema.\n"
    exit 1
fi

make clean -C targets/simple_switch/user_externs_WDRR

if make -C targets/simple_switch/user_externs_WDRR -j2; then
	info "Módulo WDRR.so compilado..."
	sudo ldconfig
fi
