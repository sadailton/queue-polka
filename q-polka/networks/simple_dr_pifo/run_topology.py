from mininet.net import Mininet
from mininet.cli import CLI
from mininet.topo import Topo
from mininet_p4_queue import P4Switch
from mininet.log import setLogLevel, info
from mininet.link import TCLink
import os


BW = 5 #Bandwidth
LOG_LEVEL="trace" #info, debug, trace

def topologia(remote_controller):

    rede = Mininet(link=TCLink)
    
    #switches = []
    #edges = []
    hosts = []
    
    host_a_mac = "aa:00:00:00:00:01"
    host_a_ip = "10.0.0.1/24"
    host_a = rede.addHost("h1", ip=host_a_ip, mac = host_a_mac)
    hosts.append(host_a)
    
    host_b_mac = "aa:00:00:00:00:02"
    host_b_ip = "10.0.0.2/24"
    host_b = rede.addHost("h2", ip=host_b_ip, mac=host_b_mac)
    hosts.append(host_b)

    # Switches P4 core
    path = os.path.dirname(os.path.relpath(__file__))
    json_file_core = os.path.join(path, "./p4/simple_switch.json")
    info(json_file_core + "\n")
    

    config_switch = os.path.join(path, "./sw_config/switch_conf.txt")
    extern_module_path = "/home/p4/p4-tools/bmv2/targets/simple_switch/user_externs_dr_pifo"
    extern_module = "DR_PIFO.so"
    dr_pifo_so = os.path.join(extern_module_path, extern_module)

    switch = rede.addSwitch("s1", netcfg=True, json=json_file_core, thriftport=51001, switch_config=config_switch, loglevel=LOG_LEVEL, cls=P4Switch, load_module=dr_pifo_so)


    # Criando os links
    info("#--- Criando os links ---#\n")
    # Links hosts to edge switches
    rede.addLink(host_a, switch, bw=BW)
    rede.addLink(host_b, switch, bw=BW)
    
    info("#--- Iniciando a rede ---#\n")
    rede.start()
    rede.staticArp()

    # disabling offload for rx and tx on each host interface
    for host in hosts:
        host.cmd("ethtool --offload {}-eth0 rx off tx off".format(host.name))
        host.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
        host.cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")

    info("*** Running CLI\n")
    CLI(rede)

    os.system("pkill -9 -f 'xterm'")

    info("*** Stopping network\n")
    rede.stop()
    
if __name__ == "__main__":
    
    setLogLevel("debug")
    remote_controller = False
    topologia(remote_controller)