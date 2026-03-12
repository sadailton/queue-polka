#!/usr/bin/env python3

# -*- coding: utf-8 -*-
import subprocess
import time
import sys
import re

def get_hostname():
    try:
        # Captura a saída do comando ifconfig
        output = subprocess.check_output(['ifconfig'], universal_newlines=True)
        # Captura a primeira interface que contém um hífen (ex: h1-eth0) no início da linha
        # e extrai tudo o que vem antes do hífen.
        match = re.search(r'^(\w+)-', output, re.MULTILINE)
        if match:
            return match.group(1)
    except FileNotFoundError:
        # Fallback caso ifconfig não esteja instalado, tenta usar comando ip
        try:
            output = subprocess.check_output(['ip', 'link'], universal_newlines=True)
            match = re.search(r'^\d+:\s+(\w+)-', output, re.MULTILINE)
            if match:
                return match.group(1)
        except Exception:
            pass
    except Exception as e:
        print(f"Erro ao executar ifconfig: {e}")
        
    return None

def run_iperf_client(host_name, port, bandwidth, duration, tos="0x00"):
    ip_h4 = "10.0.0.6"
    MTU = "1440" #Precisa ser 1400 para funcionar com PolKA
    filename = f"results_{host_name}.json"
    print(f"Configurando o {host_name}... Salvando em {filename}")
    
    # -J: Gera saída em JSON
    # --logfile: Salva direto no arquivo para evitar problemas de buffer no Python
    cmd = [
        'iperf3', '-c', ip_h4, 
        '-p', port, 
        '-b', bandwidth, 
        '-M', MTU, 
        '-i', '1',  
        '-t', duration, 
        '-J',
        '-S', tos,
        '--logfile', filename,
        '--forceflush'
    ]
    subprocess.run(cmd)

def main():
    hostname = get_hostname()
    
    ip_h1 = "10.0.0.1"
    ip_h2 = "10.0.0.2"
    ip_h3 = "10.0.0.3"
    ip_h4 = "10.0.0.4"

    
    h1_bw = "3M"
    h2_bw = "3M"
    h3_bw = "3M"
    
    # Se hostname for none e não quisermos quebrar com erro estranho
    if not hostname:
        hostname = ""

    if hostname == "h1":
        run_iperf_client("h1", "5201", h1_bw, "420", tos="0xB8")

    elif hostname == "h2":
        run_iperf_client("h2", "5202", h2_bw, "330", tos="0x28")

    elif hostname == "h3":
        run_iperf_client("h3", "5203", h3_bw, "240", tos="0xC0")

    elif hostname == "h6":
        print("Configurando o Host 4 (Servidor de Monitoramento)...")
        # No servidor, o JSON s  gerado após o fim de uma sesso se houver a flag --json.
        # Mas como o h4 recebe de vários, o ideal  salvar logs individuais se necessário.
        subprocess.Popen(['iperf3', '-s', '-p', '5201', '-i', '1', '-D']) # -D roda como daemon (background)
        subprocess.Popen(['iperf3', '-s', '-p', '5202', '-i', '1', '-D'])     
        subprocess.Popen(['iperf3', '-s', '-p', '5203', '-i', '1', '-D'])
        #subprocess.Popen(['xterm', '-e', 'iperf3', '-s', '-p', '5202', '-i', '1'])     
        #subprocess.Popen(['xterm', '-e', 'iperf3', '-s', '-p', '5203', '-i', '1'])
    else:
        print(f"Erro: Host '{hostname}' não reconhecido ou fora do intervalo h1-h4.")
        sys.exit(1)

if __name__ == "__main__":
    main()
