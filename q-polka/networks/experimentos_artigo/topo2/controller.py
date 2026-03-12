#!/usr/bin/env python3
import subprocess
import sys

switches: dict = {
        "core1": 52001,
        "core2": 52002,
        "core3": 52003,
        "core4": 52004,
        "edge1": 52101,
        "edge2": 52102,
        "edge3": 52103,
        "edge4": 52104
    }

POLKA_H1_PATHS: dict[str, dict[str, str]] = {
    "path1q1": {
        "ida": "5515473570042297734",
        "volta": "9095667555053079849"
    },
    "path1q2": {
        "ida": "5515473570042297733",
        "volta": "9095667555053079850"
    },
    "path2q1": {
        "ida": "15051264787334585140",
        "volta": "14510690083404523279"
    },
    "path2q2": {
        "ida": "15051264787334585143",
        "volta": "14510690083404523276"
    }
}

def modificar_entrada_tabela(thrift_port, table_name, handle_id, action_name, action_params):
    """
    Modifica uma entrada existente no switch BMv2.
    """
    # 1. Monta o comando exato que seria digitado no terminal
    comando_cli = f"table_modify {table_name} {action_name} {handle_id} {action_params}\n"
    
    print(f"[*] Enviando comando para porta {thrift_port}: {comando_cli.strip()}")

    # 2. Prepara a chamada do executável do BMv2
    executavel = ["simple_switch_CLI", "--thrift-port", str(thrift_port)]

    try:
        # 3. Executa o comando, injetando o texto via 'stdin' (entrada padrão)
        resultado = subprocess.run(
            executavel,
            input=comando_cli,
            text=True,           # Garante que lidamos com Strings e não Bytes
            capture_output=True, # Captura o que o switch responder
            check=True           # Gera uma exceção se der erro
        )
        
        # 4. Verifica se a palavra 'modified' está na resposta do switch
        if "has been modified" in resultado.stdout:
            print("[+] Sucesso! A regra foi alterada.")
            # print(resultado.stdout) # Descomente para ver a resposta completa
        else:
            print("[-] Comando enviado, mas verifique a saída:")
            print(resultado.stdout)

    except subprocess.CalledProcessError as e:
        print(f"[!] Erro fatal ao tentar conectar no switch: {e.stderr}")
    except FileNotFoundError:
        print("[!] Erro: 'simple_switch_CLI' não foi encontrado no PATH do sistema.")

def table_dump(thrift_port, table_name):
    """
    Dump de uma tabela no switch BMv2.
    """
    # 1. Monta o comando exato que seria digitado no terminal
    comando_cli = f"table_dump {table_name}\n"
    
    print(f"[*] Enviando comando para porta {thrift_port}: {comando_cli.strip()}")

    # 2. Prepara a chamada do executável do BMv2
    executavel = ["simple_switch_CLI", "--thrift-port", str(thrift_port)]

    try:
        # 3. Executa o comando, injetando o texto via 'stdin' (entrada padrão)
        resultado = subprocess.run(
            executavel,
            input=comando_cli,
            text=True,           # Garante que lidamos com Strings e não Bytes
            capture_output=True, # Captura o que o switch responder
            check=True           # Gera uma exceção se der erro
        )
        
        # 4. Verifica se a palavra 'dumped' está na resposta do switch
        if "dumped" in resultado.stdout:
            print("[+] Sucesso! A tabela foi dumpada.")
            # print(resultado.stdout) # Descomente para ver a resposta completa
        else:
            print("[-] Comando enviado, mas verifique a saída:")
            print(resultado.stdout)

    except subprocess.CalledProcessError as e:
        print(f"[!] Erro fatal ao tentar conectar no switch: {e.stderr}")
    except FileNotFoundError:
        print("[!] Erro: 'simple_switch_CLI' não foi encontrado no PATH do sistema.")

def menu() -> int:
    print("\n\n")
    print("1 - Alterar caminho do h1 para s1 -> s3, fila 1")
    print("2 - Alterar caminho do h1 para s1 -> s3, fila 2")
    print("3 - Alterar caminho do h1 para s2 -> s4, fila 1")
    print("4 - Alterar caminho do h1 para s2 -> s4, fila 2")
    print("5 - Sair")
    print("\n\n")
    opcao = int(input("Digite a opção desejada: "))
    return opcao

def altera_caminho(switches = switches, POLKA_H1_PATHS = POLKA_H1_PATHS, opcao_menu: int = 0):
    
    opcao = menu()
    #opcao = opcao_menu

    nome_tabela = "MyIngress.tunnel_encap_process_sr"
    action_name = "add_sourcerouting_header"
    handle_id = "1"
    
    while opcao != 5:
        match opcao:
            case 1:
                # Ida s1 -> s3, fila 1
                thrift_port = switches["edge1"]
                NOVO_ROUTEID = POLKA_H1_PATHS["path1q1"]["ida"]
                action_params = f"2 1 aa:00:00:00:00:04 {NOVO_ROUTEID}"
                modificar_entrada_tabela(
                    thrift_port=thrift_port,
                    table_name=nome_tabela,
                    handle_id=handle_id,
                    action_name=action_name,
                    action_params=action_params
                )
                # Volta s3 -> s1, fila 1
                thrift_port = switches["edge4"]
                NOVO_ROUTEID = POLKA_H1_PATHS["path1q1"]["volta"]
                action_params = f"2 1 aa:00:00:00:00:01 {NOVO_ROUTEID}"
                modificar_entrada_tabela(
                    thrift_port=thrift_port,
                    table_name=nome_tabela,
                    handle_id=handle_id,
                    action_name=action_name,
                    action_params=action_params
                )
            case 2:
                # Ida s1 -> s3, fila 2
                thrift_port = switches["edge1"]
                NOVO_ROUTEID = POLKA_H1_PATHS["path1q2"]["ida"]
                action_params = f"2 1 aa:00:00:00:00:04 {NOVO_ROUTEID}"
                modificar_entrada_tabela(
                    thrift_port=thrift_port,
                    table_name=nome_tabela,
                    handle_id=handle_id,
                    action_name=action_name,
                    action_params=action_params
                )
                # Volta s3 -> s1, fila 2
                thrift_port = switches["edge4"]
                NOVO_ROUTEID = POLKA_H1_PATHS["path1q2"]["volta"]
                action_params = f"2 1 aa:00:00:00:00:01 {NOVO_ROUTEID}"
                modificar_entrada_tabela(
                    thrift_port=thrift_port,
                    table_name=nome_tabela,
                    handle_id=handle_id,
                    action_name=action_name,
                    action_params=action_params
                )
            case 3:
                # Ida
                # s2 -> s4, fila 1
                thrift_port = switches["edge2"]
                NOVO_ROUTEID = POLKA_H1_PATHS["path2q1"]["ida"]
                action_params = f"3 1 aa:00:00:00:00:04 {NOVO_ROUTEID}"
                modificar_entrada_tabela(
                    thrift_port=thrift_port,
                    table_name=nome_tabela,
                    handle_id=handle_id,
                    action_name=action_name,
                    action_params=action_params
                )
                # Volta s4 -> s2, fila 1
                thrift_port = switches["edge4"]
                NOVO_ROUTEID = POLKA_H1_PATHS["path2q1"]["volta"]
                action_params = f"3 1 aa:00:00:00:00:01 {NOVO_ROUTEID}"
                modificar_entrada_tabela(
                    thrift_port=thrift_port,
                    table_name=nome_tabela,
                    handle_id=handle_id,
                    action_name=action_name,
                    action_params=action_params
                )
            case 4:
                # Ida
                # s2 -> s4, fila 2
                thrift_port = switches["edge2"]
                NOVO_ROUTEID = POLKA_H1_PATHS["path2q2"]["ida"]
                action_params = f"3 1 aa:00:00:00:00:04 {NOVO_ROUTEID}"
                modificar_entrada_tabela(
                    thrift_port=thrift_port,
                    table_name=nome_tabela,
                    handle_id=handle_id,
                    action_name=action_name,
                    action_params=action_params
                )
                # Volta s4 -> s2, fila 2
                thrift_port = switches["edge4"]
                NOVO_ROUTEID = POLKA_H1_PATHS["path2q2"]["volta"]
                action_params = f"3 1 aa:00:00:00:00:01 {NOVO_ROUTEID}"
                modificar_entrada_tabela(
                    thrift_port=thrift_port,
                    table_name=nome_tabela,
                    handle_id=handle_id,
                    action_name=action_name,
                    action_params=action_params
                )
            case 5:
                break
            case _:
                print("Opção inválida!")
                
        opcao = menu()

def altera_caminho_sem_menu(switches = switches, POLKA_H1_PATHS = POLKA_H1_PATHS, opcao_menu: int = 0):
    
    
    opcao = opcao_menu

    nome_tabela = "MyIngress.tunnel_encap_process_sr"
    action_name = "add_sourcerouting_header"
    handle_id = "1"
    
    match opcao:
        case 1:
            # Ida s1 -> s3, fila 1
            thrift_port = switches["edge1"]
            NOVO_ROUTEID = POLKA_H1_PATHS["path1q1"]["ida"]
            action_params = f"2 1 aa:00:00:00:00:04 {NOVO_ROUTEID}"
            modificar_entrada_tabela(
                thrift_port=thrift_port,
                table_name=nome_tabela,
                handle_id=handle_id,
                action_name=action_name,
                action_params=action_params
            )
            # Volta s3 -> s1, fila 1
            thrift_port = switches["edge4"]
            NOVO_ROUTEID = POLKA_H1_PATHS["path1q1"]["volta"]
            action_params = f"2 1 aa:00:00:00:00:01 {NOVO_ROUTEID}"
            modificar_entrada_tabela(
                thrift_port=thrift_port,
                table_name=nome_tabela,
                handle_id=handle_id,
                action_name=action_name,
                action_params=action_params
            )
        case 2:
            # Ida s1 -> s3, fila 2
            thrift_port = switches["edge1"]
            NOVO_ROUTEID = POLKA_H1_PATHS["path1q2"]["ida"]
            action_params = f"2 1 aa:00:00:00:00:04 {NOVO_ROUTEID}"
            modificar_entrada_tabela(
                thrift_port=thrift_port,
                table_name=nome_tabela,
                handle_id=handle_id,
                action_name=action_name,
                action_params=action_params
            )
            # Volta s3 -> s1, fila 2
            thrift_port = switches["edge4"]
            NOVO_ROUTEID = POLKA_H1_PATHS["path1q2"]["volta"]
            action_params = f"2 1 aa:00:00:00:00:01 {NOVO_ROUTEID}"
            modificar_entrada_tabela(
                thrift_port=thrift_port,
                table_name=nome_tabela,
                handle_id=handle_id,
                action_name=action_name,
                action_params=action_params
            )
        case 3:
            # Ida
            # s2 -> s4, fila 1
            thrift_port = switches["edge2"]
            NOVO_ROUTEID = POLKA_H1_PATHS["path2q1"]["ida"]
            action_params = f"3 1 aa:00:00:00:00:04 {NOVO_ROUTEID}"
            modificar_entrada_tabela(
                thrift_port=thrift_port,
                table_name=nome_tabela,
                handle_id=handle_id,
                action_name=action_name,
                action_params=action_params
            )
            # Volta s4 -> s2, fila 1
            thrift_port = switches["edge4"]
            NOVO_ROUTEID = POLKA_H1_PATHS["path2q1"]["volta"]
            action_params = f"3 1 aa:00:00:00:00:01 {NOVO_ROUTEID}"
            modificar_entrada_tabela(
                thrift_port=thrift_port,
                table_name=nome_tabela,
                handle_id=handle_id,
                action_name=action_name,
                action_params=action_params
            )
        case 4:
            # Ida
            # s2 -> s4, fila 2
            thrift_port = switches["edge2"]
            NOVO_ROUTEID = POLKA_H1_PATHS["path2q2"]["ida"]
            action_params = f"3 1 aa:00:00:00:00:04 {NOVO_ROUTEID}"
            modificar_entrada_tabela(
                thrift_port=thrift_port,
                table_name=nome_tabela,
                handle_id=handle_id,
                action_name=action_name,
                action_params=action_params
            )
            # Volta s4 -> s2, fila 2
            thrift_port = switches["edge4"]
            NOVO_ROUTEID = POLKA_H1_PATHS["path2q2"]["volta"]
            action_params = f"3 1 aa:00:00:00:00:01 {NOVO_ROUTEID}"
            modificar_entrada_tabela(
                thrift_port=thrift_port,
                table_name=nome_tabela,
                handle_id=handle_id,
                action_name=action_name,
                action_params=action_params
            )
        case _:
            print("Opção inválida!")

if __name__ == "__main__":
    # --- CONFIGURAÇÕES PARA O SEU EXPERIMENTO ---
    
    # Porta do Switch (sw1 = 9090, sw2 = 9091, etc)
    

    # Dispara a função
    altera_caminho(switches, POLKA_H1_PATHS)

    exit(0)
