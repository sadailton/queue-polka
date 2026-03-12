import json
import matplotlib.pyplot as plt
import os

def extrair_vazao_iperf_json(arquivo):
    vazao = []
    tempos = []
    
    if not os.path.exists(arquivo):
        print(f"Arquivo {arquivo} não encontrado.")
        return tempos, vazao

    with open(arquivo, 'r') as f:
        try:
            dados = json.load(f)
            
            # O iperf3 armazena os dados segundo a segundo dentro do array "intervals"
            if 'intervals' in dados:
                for intervalo in dados['intervals']:
                    # O bloco "sum" contém o consolidado do tráfego daquele intervalo
                    if 'sum' in intervalo:
                        tempo_fim = float(intervalo['sum']['end'])
                        
                        # O iperf3 entrega a banda em bps. Dividimos por 1.000.000 para Mbps
                        banda_mbps = float(intervalo['sum']['bits_per_second']) / 1_000_000.0
                        
                        tempos.append(tempo_fim)
                        vazao.append(banda_mbps)
                        
        except json.JSONDecodeError:
            print(f"[!] Erro ao ler {arquivo}. O arquivo pode estar corrompido ou o iperf3 foi interrompido abruptamente.")
                
    return tempos, vazao

# 1. Extração dos Dados (Agora lendo os JSONs)
tempos_h1, vazao_h1 = extrair_vazao_iperf_json('results_h1.json')
tempos_h2, vazao_h2 = extrair_vazao_iperf_json('results_h2.json')
tempos_h3, vazao_h3 = extrair_vazao_iperf_json('results_h3.json')

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
plt.ylim(0, 6) # Ajuste o limite Y se a sua banda total for diferente
plt.grid(True, linestyle='--', alpha=0.7)
plt.legend(loc='upper right', fontsize=10, framealpha=1)

# 4. Salvando em alta resolução para o artigo (DPI 300)
plt.tight_layout()
plt.savefig('grafico_vazao_slicing.png', dpi=300, bbox_inches='tight')
plt.savefig('grafico_vazao_slicing.pdf') # Versão vetorizada (melhor para LaTeX)

print("Gráficos gerados com sucesso: 'grafico_vazao_slicing.png' e 'grafico_vazao_slicing.pdf'")
plt.show()