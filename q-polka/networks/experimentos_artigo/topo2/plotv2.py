import matplotlib.pyplot as plt
import re
import os

def extrair_vazao_iperf(arquivo):
    vazao = []
    tempos = []
    
    if not os.path.exists(arquivo):
        print(f"Arquivo {arquivo} não encontrado.")
        return tempos, vazao

    with open(arquivo, 'r') as f:
        linhas = f.readlines()
        
        for linha in linhas:
            # Ignora o cabeçalho e o rodapé estatístico do iperf3
            if "- - - -" in linha or "out-of-order" in linha:
                continue
                
            # Regex para capturar o tempo (ex: 0.00-1.00) e a banda (ex: 2.50 Mbits/sec)
            match = re.search(r'\]\s+(\d+\.\d+)-\s*(\d+\.\d+)\s+sec.*\s+(\d+\.\d+)\s+[MK]bits/sec', linha)
            if match:
                tempo_fim = float(match.group(2))
                banda = float(match.group(3))
                
                # Se a unidade for Kbits, converte para Mbits
                if "Kbits/sec" in linha:
                    banda = banda / 1000.0
                    
                tempos.append(tempo_fim)
                vazao.append(banda)
                
    return tempos, vazao

# 1. Extração dos Dados
tempos_h1, vazao_h1 = extrair_vazao_iperf('resultado_h1.txt')
tempos_h2, vazao_h2 = extrair_vazao_iperf('resultado_h2.txt')
tempos_h3, vazao_h3 = extrair_vazao_iperf('resultado_h3.txt')

# 2. Configuração do Gráfico Estilo Artigo Científico
plt.figure(figsize=(10, 6))

# Plotando as linhas com marcadores e estilos diferentes (bom para impressão em P&B)
if vazao_h1:
    plt.plot(tempos_h1, vazao_h1, label='Slice 1 - VIP (50%)', color='blue', linestyle='-', linewidth=2)
if vazao_h2:
    plt.plot(tempos_h2, vazao_h2, label='Slice 2 - Normal (30%)', color='green', linestyle='--', linewidth=2)
if vazao_h3:
    plt.plot(tempos_h3, vazao_h3, label='Slice 3 - Best Effort (20%)', color='red', linestyle=':', linewidth=2)

# Linha preta tracejada para mostrar o limite teórico do switch (5 Mbps)
plt.axhline(y=5.0, color='black', linestyle='-.', label='Capacidade do Link (5 Mbps)')

# 3. Formatação
plt.title('Isolamento de Fatias de Rede (Network Slicing) via PolKA + WDRR', fontsize=14, fontweight='bold')
plt.xlabel('Tempo (segundos)', fontsize=12)
plt.ylabel('Vazão (Mbps)', fontsize=12)
plt.ylim(0, 6) # Ajuste o eixo Y para ir de 0 a 6 Mbps
plt.grid(True, linestyle='--', alpha=0.7)
plt.legend(loc='upper right', fontsize=10, framealpha=1)

# 4. Salvando em alta resolução para o artigo (DPI 300)
plt.tight_layout()
plt.savefig('grafico_vazao_slicing.png', dpi=300, bbox_inches='tight')
plt.savefig('grafico_vazao_slicing.pdf') # Versão vetorizada (melhor para LaTeX)

print("Gráficos gerados com sucesso: 'grafico_vazao_slicing.png' e '.pdf'")
plt.show()