from mininet.net import Mininet
from mininet.topo import Topo
from mininet.log import setLogLevel
from mininet.cli import CLI
#from p4_mininet import P4Switch, P4Host
from mininet_p4_queue import P4Switch, P4Host
import os


# Path to your compiled JSON and your custom binary
SW_PATH = "/usr/local/bin/simple_switch_grpc" # <--- UPDATE THIS
JSON_PATH = "./p4/dr_pifo_test.json"

class SingleSwitchTopo(Topo):
    def __init__(self, **opts):
        Topo.__init__(self, **opts)

        # Add 2 Hosts
        h1 = self.addHost('h1', ip='10.0.0.1/24', mac='00:00:00:00:00:01')
        h2 = self.addHost('h2', ip='10.0.0.2/24', mac='00:00:00:00:00:02')

        # Switches P4 core
        path = os.path.dirname(os.path.relpath(__file__))
        json_file_core = os.path.join("/home/p4/queue-polka/q-polka/networks/simple_dr_pifo/p4/simple_switch.json")
        #info(json_file_core + "\n")
        
        LOG_LEVEL="trace" #info, debug, trace
        config_switch = os.path.join(path, "./sw_config/switch_conf.txt")
        extern_module_path = "/home/p4/p4-tools/bmv2/targets/simple_switch/user_externs_dr_pifo"
        extern_module = "DR_PIFO.so"
        dr_pifo_so = os.path.join(extern_module_path, extern_module)

        s1 = self.addSwitch("s1", netcfg=True, json=json_file_core, thriftport=51001, switch_config=config_switch, loglevel=LOG_LEVEL, cls=P4Switch, load_module=dr_pifo_so)


        # Add 1 Switch
        # s1 = self.addSwitch('s1', 
        #                    sw_path=SW_PATH,
        #                    json_path=JSON_PATH,
        #                    thrift_port=9090,
        #                    pcap_dump=True) # Enables PCAP to debug

        self.addLink(h1, s1)
        self.addLink(h2, s1)

def run():
    topo = SingleSwitchTopo()
    net = Mininet(topo=topo, host=P4Host, switch=P4Switch, controller=None)
    net.start()

    print("--- Configuring Table Entries ---")
    # Program the forwarding table using simple_switch_CLI
    # h1 (port 1) <-> s1 <-> h2 (port 2)
    import os
    cmd_h1 = 'echo "table_add ipv4_lpm ipv4_forward 10.0.0.1/32 => 1" | simple_switch_CLI --thrift-port 9090'
    cmd_h2 = 'echo "table_add ipv4_lpm ipv4_forward 10.0.0.2/32 => 2" | simple_switch_CLI --thrift-port 9090'
    os.system(cmd_h1)
    os.system(cmd_h2)

    print("--- Configurando ARP Estático ---")

    # Busca os objetos h1 e h2 dentro da rede instanciada
    h1 = net.get('h1')
    h2 = net.get('h2')

    h1.cmd("arp -s 10.0.0.2 00:00:00:00:00:02")
    h2.cmd("arp -s 10.0.0.1 00:00:00:00:00:01")

    print("--- Ready. You can now try: h1 ping h2 ---")
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    run()