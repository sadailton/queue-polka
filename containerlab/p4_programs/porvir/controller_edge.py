#!/bin/env python3
import grpc
import logging
import ipaddress
import random
import codecs
from load_table_info import *


# Importações corretas baseadas no seu client.py
from bfrt_grpc.client import ClientInterface, Target, KeyTuple, DataTuple
from bfrt_grpc.client import BfruntimeRpcException

# --- 1. Configurações de Conexão e P4 (Atualizadas) ---
DEVICE_ID = 0
CLIENT_ID = 0 
BFRT_ADDRESS = 'localhost:50052' # A porta BFRT gRPC correta
PROGRAM_NAME = "polka_edge"      # Nome do seu pipeline
TABLE_NAME = "pipe.Ingress.process_tunnel_encap.tunnel_encap_process_sr"
ACTION_NAME = "Ingress.process_tunnel_encap.add_sourcerouting_header"

LOGGER = logging.getLogger('ControlPlane')
LOGGER.setLevel(logging.INFO)
logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.INFO)


# --- Funções Auxiliares ---

def mac_to_int(addr_str):
    """Converte um MAC string 'aa:bb:cc:dd:ee:ff' para um inteiro."""
    return int(addr_str.replace(':', ''), 16)

def int_to_bytes(n, length):
    """Converte um inteiro para um bytearray de tamanho fixo (Big Endian)."""
    # Esta é uma reimplementação simples da função 'to_bytes' do client.py
    h = '%x' % n
    s = h.zfill(length * 2)
    return bytearray(codecs.decode(s, "hex"))


# --- Função Principal de População ---

def populate_tunnel_table(interface: ClientInterface, table_key_name: str, data_to_add: list[tuple]):
    """Conecta e popula a tabela de túnel SR."""
    
    # 1. Obtém o objeto bfrt_info
    bfrt_info = interface.bfrt_info_get(PROGRAM_NAME)

    # 2. Acessa a tabela específica
    try:
        tunnel_table = bfrt_info.table_get(TABLE_NAME)
        
    except Exception as e:
        LOGGER.error(f"Erro ao obter tabela {TABLE_NAME}. Verifique o nome do pipeline e da tabela. Erro: {e}")
        return
    

    # 3. Adiciona anotação para o campo IP (boa prática, como no exemplo do SDE)
    #tunnel_table.info.key_field_annotation_add("hdr.ipv4.dst_addr", "ipv4")

    # 4. Target (Aplica a todos os 'pipes')
    target = Target(device_id=DEVICE_ID, pipe_id=0xffff)

    # 5. Limpar Entradas Antigas (Opcional)
    tunnel_table.entry_del(target)
    LOGGER.info(f"Tabela '{TABLE_NAME}' limpa com sucesso.")
    
    # --- 6. Definição das Regras de Encaminhamento ---

    # Lista de regras a serem inseridas: 
    # (dst_ip, p_len, port, sr_flag, dmac_str, route_id)
    #entries_to_add = [
    #    ("10.10.1.1", 32, 3, 1, "aa:c1:ab:13:07:46", 2),
    #    ("10.10.1.2", 32, 2, 0, "aa:c1:ab:16:82:5b", 0),
    #]

    # 7. Inserção das Entradas
    for ip_addr, prefix_length, mac_destino, porta_saida, route_id, apply_polka in data_to_add:
        
        # Constrói a Chave de Match (Key)
        # O campo 'dstAddr' é LPM (requer IP e prefixo)
        ip_as_int = int(ipaddress.IPv4Address(ip_addr))
        key = tunnel_table.make_key([
            KeyTuple(table_key_name, ip_as_int, prefix_len=prefix_length) 
        ])
        
        # Constrói os Dados da Ação (Data)
        data = tunnel_table.make_data([
            DataTuple('port', porta_saida),                   # size 9
            DataTuple('sr', apply_polka),                 # size 1
            DataTuple('dmac', mac_to_int(mac_destino)),  # size 48
            DataTuple('routeIdPacket', route_id)   # size 160 (passado como bytearray)
        ], ACTION_NAME) # Nome da ação

        try:
            tunnel_table.entry_add(target, [key], [data])
            LOGGER.info(f"Adicionado LPM: {ip_addr}/{prefix_length} -> Porta {porta_saida}, DMAC {mac_destino}")
        except BfruntimeRpcException as e:
            LOGGER.error(f"Falha ao adicionar entrada {ip_addr}/{prefix_length}: {e}")
            
    # 8. Confirmação (GET/Dump)
    LOGGER.info("\nVerificando entradas inseridas (Dump):")

    try: 
        response = tunnel_table.entry_get(target, flags={"from_hw": True})

        #print(f"### response: {response} ###")

        for data, key in response:
            key_dict = key.to_dict()
            data_dict = data.to_dict()
            
            #print(f"### key_dict: {key_dict['hdr.ipv4.dstAddr']} ###")
            #print(f"### data_dict: {data_dict} ###")

            ip_addr_as_int = key_dict[table_key_name]['value']
            ip_addr = str(ipaddress.IPv4Address(ip_addr_as_int))
            prefix_len = key_dict[table_key_name]['prefix_len']

            LOGGER.info(f"Encontrado: {ip_addr}/{prefix_len} -> Dados: {data_dict}")

    except Exception as e:
        LOGGER.error(f"Falha ao obter entradas da tabela: {e}")
        return
    
# --- Execução do Script ---

if __name__ == '__main__':
    try:
        # Instanciação da conexão
        interface = ClientInterface(
            grpc_addr=BFRT_ADDRESS,
            client_id=CLIENT_ID,
            device_id=DEVICE_ID,
            perform_subscribe=True # Cliente simples de controle
        )
        
        # Faz o "bind" do cliente ao programa P4 antes de interagir
        interface.bind_pipeline_config(PROGRAM_NAME)
        
        data_to_add: tuple = ()
        table_key_name: str = ""
        
        table_key_name, data_to_add = get_table_data()

        populate_tunnel_table(interface, table_key_name, data_to_add)
        
    except Exception as e:
        LOGGER.critical(f"Falha Crítica na execução do Control Plane: {e}")
        LOGGER.critical(f"Verifique se o Tofino Model ({PROGRAM_NAME}) está ativo em {BFRT_ADDRESS}.")