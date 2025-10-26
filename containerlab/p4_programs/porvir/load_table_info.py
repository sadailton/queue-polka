#from box import Box
import json
import socket
import os

_JSON_FILE = os.path.join(os.path.dirname(__file__), "table_info_edge.json")
_hostname = socket.gethostname()

def load_table_info(arquivo_json):

    data: json = {}

    with open(arquivo_json, "r") as f:
        data = json.load(f)

    return data

def get_table_data():

    json_data = load_table_info(_JSON_FILE)

    router_data: json = json_data[_hostname]
    table_data: list[tuple] = []

    table_key_name: str = router_data["table_key_name"]

    for dado in router_data["table_data"]:
        table_key: str = dado["table_key"]
        mac_destino: str = dado["mac_destino"]
        porta_saida: int = dado["porta"]
        route_id: int = dado["route_id"]
        apply_polka: int = dado["apply_polka"]

        # Neste caso a chave da tabela é o endereço IP que deve ser
        # passado separado da máscara de rede.
        ip_addr = table_key.split('/')[0]
        prefix_length: int = int(table_key.split('/')[1])

        table_data.append((ip_addr, prefix_length, mac_destino, porta_saida, route_id, apply_polka))

    return table_key_name, table_data



    