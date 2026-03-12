import json
import matplotlib.pyplot as plt

def plot_synchronized_iperf(filenames, limit_mbps=5.0, total_duration=90):
    datasets = []
    global_start_time = float('inf')

    # Passo 1: Ler arquivos e encontrar o timestamp de início global
    for filename in filenames:
        try:
            with open(filename, 'r') as f:
                data = json.load(f)
                
                # Tratamento do Timestamp (evita erro de dicionário vs float)
                ts_data = data['start']['timestamp']
                if isinstance(ts_data, dict):
                    # No iperf3 moderno, o timestamp é um dict com a chave 'timesecs'
                    start_timestamp = float(ts_data['timesecs'])
                else:
                    start_timestamp = float(ts_data)
                
                if start_timestamp < global_start_time:
                    global_start_time = start_timestamp
                
                datasets.append((filename, data, start_timestamp))
        except Exception as e:
            print(f"Erro ao ler {filename}: {e}")

    if not datasets:
        print("Nenhum dado válido para plotar.")
        return

    # Passo 2: Configuração do Gráfico
    plt.figure(figsize=(12, 6))

    for filename, data, start_timestamp in datasets:
        # Sincronização temporal
        offset = start_timestamp - global_start_time
        
        intervals = data['intervals']
        
        # Cálculo: (Banda_Atual / 5Mbps) * 100
        percentages = [(i['sum']['bits_per_second'] / 1e6 / limit_mbps) * 100 for i in intervals]
        
        # Eixo X ajustado com o offset do início do fluxo
        relative_seconds = [i['sum']['start'] + offset for i in intervals]

        plt.plot(relative_seconds, percentages, label=f'Fluxo {filename}', linewidth=2)

    # Estética e Limites
    plt.title('Monitoramento de Banda Sincronizado (Carga Relativa %)', fontsize=14)
    plt.xlabel('Tempo Total de Simulação (s)', fontsize=12)
    plt.ylabel('Uso da Banda (100% = 5 Mbps)', fontsize=12)
    plt.xlim(0, total_duration)
    plt.ylim(0, 110)
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.axhline(y=100, color='r', linestyle=':', label='Limite 5Mbps')
    plt.legend(loc='upper right')

    # Passo 3: Salvar e Mostrar
    plt.tight_layout()
    plt.savefig('grafico_final.png', dpi=300) # Salva com alta resolução
    print("Gráfico salvo com sucesso como 'grafico_final.png'")
    plt.show()

# Execução
arquivos = ['results_h1.json', 'results_h2.json', 'results_h3.json']
plot_synchronized_iperf(arquivos, limit_mbps=5.0, total_duration=90)