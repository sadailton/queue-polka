# -*- coding: utf-8 -*-

import json
import matplotlib.pyplot as plt
import numpy as np

def smooth_data(data, window_size=5):
    """Suaviza os dados usando média móvel."""
    if len(data) < window_size: return data
    return np.convolve(data, np.ones(window_size)/window_size, mode='same')

def plot_final(filenames, limit_mbps=5.0, total_duration=420):
    datasets = []
    global_start = float('inf')

    # Carregar dados e sincronizar tempo
    for fname in filenames:
        try:
            with open(fname, 'r') as f:
                data = json.load(f)
                ts = data['start']['timestamp']
                start_ts = float(ts['timesecs']) if isinstance(ts, dict) else float(ts)
                
                if start_ts < global_start:
                    global_start = start_ts
                datasets.append((fname, data, start_ts))
        except Exception as e:
            print(f"Erro ao ler {fname}: {e}")

    plt.figure(figsize=(12, 6))

    for fname, data, start_ts in datasets:
        offset = start_ts - global_start    
        intervals = data['intervals']
        
        # Extração e conversão para porcentagem
        raw_bps = [i['sum']['bits_per_second'] for i in intervals]
        percentages = [(val / 1e6 / limit_mbps) * 100 for val in raw_bps]
        
        # Aplicação da suavização
        percentages_smoothed = smooth_data(percentages, window_size=10)
        
        seconds = [i['sum']['start'] + offset for i in intervals]

        plt.plot(seconds, percentages_smoothed, label=f'Fluxo {fname.replace(".json","")}', linewidth=2)

    # Estética do Gráfico
    plt.axhline(y=100, color='red', linestyle='--', alpha=0.5, label='Limite 5Mbps (100%)')
    plt.title('Monitoramento de Banda Sincronizado e Suavizado', fontsize=14)
    plt.xlabel('Tempo de Simulação (s)', fontsize=12)
    plt.ylabel('Uso da Banda (%)', fontsize=12)
    plt.xlim(0, total_duration)
    plt.ylim(0, 110)
    plt.grid(True, linestyle=':', alpha=0.6)
    plt.legend(loc='upper right')
    
    plt.tight_layout()
    plt.savefig('grafico_suave.png', dpi=300)
    print("Gráfico 'grafico_suave.png' gerado com sucesso!")
    plt.show()

# Lista dos arquivos coletados
arquivos = ['results_h1.json', 'results_h2.json', 'results_h3.json']
plot_final(arquivos)