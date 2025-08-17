from mininet.net import Mininet
from mininet.cli import CLI
from mininet.topo import Topo
from mininet_p4_queue import P4Switch
from mininet.log import setLogLevel, info
import os


BW = 10 #Bandwidth

def topologia(remote_controller):

    rede = Mininet()
    
    switches = []
    edges = []
    hosts = []
    
    host_vix_mac = "86:ff:07:81:ab:ba"
    host_vix_ip = "10.0.0.1/24"
    host_vix = rede.addHost("h1", ip=host_vix_ip, mac = host_vix_mac)
    
    host_sp_mac = "2e:6a:b6:27:b6:91"
    host_sp_ip = "10.0.0.2/24"
    host_sp = rede.addHost("h2", ip=host_sp_ip, mac=host_sp_mac)
    
    # Switches P4 core
    path = os.path.dirname(os.path.relpath(__file__))
    json_file_core = os.path.join(path, "./p4/polka_core.json")
    info(json_file_core + "\n")
    
    config_core_vix = os.path.join(path, "./sw_config/s1-commands.txt")
    sw_core_vix = rede.addSwitch("s1", netcfg=True, json=json_file_core, thriftport=50001, switch_config=config_core_vix, loglevel="trace", cls=P4Switch, priority_queue_num=8)
    
    
    config_core_rj = os.path.join(path, "./sw_config/s2-commands.txt")
    sw_core_rj = rede.addSwitch("s2", netcfg=True, json=json_file_core, thriftport=50002, switch_config=config_core_rj, loglevel="trace", cls=P4Switch, priority_queue_num=8)
    
    
    config_core_mg = os.path.join(path, "./sw_config/s3-commands.txt")
    sw_core_mg = rede.addSwitch("s3", netcfg=True, json=json_file_core, thriftport=50003, switch_config=config_core_mg, loglevel="trace", cls=P4Switch, priority_queue_num=8)
    
    
    config_core_sp = os.path.join(path, "./sw_config/s4-commands.txt")
    sw_core_sp = rede.addSwitch("s4", netcfg=True, json=json_file_core, thriftport=50004, switch_config=config_core_sp, loglevel="trace", cls=P4Switch, priority_queue_num=8)
    
    
    # Switches P4 edges
    path = os.path.dirname(os.path.abspath(__file__))
    json_file_edge = os.path.join(path, "p4/polka_edge.json")
    info(json_file_edge)
        
    config = os.path.join(path, "./sw_config/e1-vix-commands.txt")
    sw_edge_vix = rede.addSwitch("e1", netcfg=True, json=json_file_edge, thriftport=50101, switch_config=config, loglevel="debug", cls=P4Switch)
    
    config = os.path.join(path, "./sw_config/e2-sp-commands.txt")
    sw_edge_sp = rede.addSwitch("e2", netcfg=True, json=json_file_edge, thriftport=50102, switch_config=config, loglevel="debug", cls=P4Switch)
    
    # Criando os links
    info("#--- Criando os links ---#\n")
    rede.addLink(host_vix, sw_edge_vix, bw=BW)
    rede.addLink(sw_edge_sp, host_sp, bw=BW)
    rede.addLink(sw_edge_vix, sw_core_vix, bw=BW)
    rede.addLink(sw_core_vix, sw_core_rj, bw=BW)
    rede.addLink(sw_core_vix, sw_core_mg, bw=BW)
    rede.addLink(sw_core_rj, sw_core_sp, bw=BW)
    rede.addLink(sw_core_mg, sw_core_sp, bw=BW)
    rede.addLink(sw_core_sp, sw_edge_sp, bw=BW)
    
    
    info("#--- Iniciando a rede ---#\n")
    rede.start()
    rede.staticArp()

    # disabling offload for rx and tx on each host interface
    for host in hosts:
        host.cmd("ethtool --offload {}-eth0 rx off tx off".format(host.name))

    info("*** Running CLI\n")
    CLI(rede)

    os.system("pkill -9 -f 'xterm'")

    info("*** Stopping network\n")
    rede.stop()
    
if __name__ == "__main__":
    
    setLogLevel("info")
    remote_controller = False
    topologia(remote_controller)