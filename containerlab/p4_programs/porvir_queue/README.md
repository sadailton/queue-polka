
## Documentação dos arquivos de configuração desta topologia

### table_info_edge.json

Neste arquivo estão as configurações da porta de saída, routeID, endereço mac do host de destino, endereço IP que é usado como chave de pesquisa na tabela e o nome da tabela em que as informações mencionadas devem ser inseridas.

Para alterar uma rota entre dois hosts, basta gerar um novo routeID dessa rota e atualizar este arquivo.

### init_tofino_core.sh

É executado durante a instanciação do container que faz o papel do switch core da topologia. Ele é chamado nos nós core# (# é um numero inteiro) declarados no arquivo `porvir.clab.yml`.

### init_tofino_edge.sh

É executado durante a instanciação do container que faz o papel do switch edge da topologia. Ele é chamado nos nós edge# (# é um numero inteiro) declarados no arquivo `porvir.clab.yml`.

### config_hosts.sh

Script para configurar o endereço MAC, IP e tabela ARP dos hosts. A configuração da tabela arp manualmente nos hosts é necessária porque não está implementado o protocolo ARP no código P4 dos switches. Este é o primeiro script que deve ser executado após a inicialização da topologia.

### config_edges.sh

Script que executa o arquivo `controller_edge.py` dentro de cada container que faz o papel de switch edge da topologia. Deve ser executado após o `config_hosts.sh` ou sempre que houver alteração no arquivo `table_info_edge.json` para que essas alterações sejam apliadas. 

### load_table_info.py

Script que lê o arquivo `table_info_edge.json` e passa as informações para o `controller_edge.py`. O `load_table_info.py` é importado pelo arquivo `controller_edge.py` que por sua vez é executado durante a execução do script `config_edges.sh`.

### Makefile_core

Arquivo que contém os comandos e parâmetros necessários para a compilação do código P4 dos switches core. A compilação ocorre durante a inicialização dos nós core.

### Makefile_edge

Arquivo que contém os comandos e parâmetros necessários para a compilação do código P4 dos switches edge. A compilação ocorre durante a inicialização dos nós edge.

### portinfo_if.json

Arquivo de mapeamento das interfaces do sistema operacional onde o processo do switch tofino está sendo executado com as portas desse switch. Ele é passado como parâmetro na inicialização do switch (o switch em si, não o container) nos arquivo `init_tofino_core.sh` e `init_tofino_edge.sh`.

> [!WARNING]  
> Para o calculo do routeID, deve ser considerado o seguinte mapeamento de interface do host com as portas do switch:  
> eth1 -> porta 2, eth2 -> porta 3, eth3 -> porta4...  
> Isso porque a porta 1 do switch tofino é reservada para recirculação de pacotes. Este mapeamento está declarado no arquivo `portinfo_if.json`

### Tabela de routeIDs dos caminhos

| Link | Hops | RouteID |
| ---- | ---- | ------- |
| host1 -> host2 | core1, core2 |  2147385797 |
| host2 -> host1 | core2, core1 | 2147451375 |
| host1 -> host3 | core1, core2, core3 | 35172569164509 |
| host1 -> host3 | core1, core4, core3 | 61189574326532 |
| host3 -> host1 | core3, core2, core1 | 15081013684063 |
| host2 -> host3 | core2, core3 | 357843069 |
| host3 -> host2 | core3, core2 | 2147057926 |
| host4 -> host3 | core4, core3 | 2147451286 |
| host3 -> host4 | core3, core4 | 2147385774 |
