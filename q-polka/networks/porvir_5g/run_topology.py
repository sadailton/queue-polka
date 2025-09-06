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
    
    host_vix_mac = "aa:00:00:00:00:01"
    host_vix_ip = "10.0.0.1/24"
    host_vix = rede.addHost("h1", ip=host_vix_ip, mac = host_vix_mac)
    hosts.append(host_vix)
    
    host_mg_mac = "aa:00:00:00:00:02"
    host_mg_ip = "10.0.0.2/24"
    host_mg = rede.addHost("h2", ip=host_mg_ip, mac=host_mg_mac)
    hosts.append(host_mg)

    host_rj_mac = "aa:00:00:00:00:03"
    host_rj_ip = "10.0.0.3/24"
    host_rj = rede.addHost("h3", ip=host_rj_ip, mac=host_rj_mac)
    hosts.append(host_rj)

    host_sp_mac = "aa:00:00:00:00:04"
    host_sp_ip = "10.0.0.4/24"
    host_sp = rede.addHost("h4", ip=host_sp_ip, mac=host_sp_mac)
    hosts.append(host_sp)


    # Switches P4 core
    path = os.path.dirname(os.path.relpath(__file__))
    json_file_core = os.path.join(path, "./p4/polka_core.json")
    info(json_file_core + "\n")
    
    config_core_vix = os.path.join(path, "./sw_config/s1-commands.txt")
    sw_core_vix = rede.addSwitch("s1", netcfg=True, json=json_file_core, thriftport=51001, switch_config=config_core_vix, loglevel=LOG_LEVEL, cls=P4Switch, priority_queue_num=8)
    
    config_core_mg = os.path.join(path, "./sw_config/s2-commands.txt")
    sw_core_mg = rede.addSwitch("s2", netcfg=True, json=json_file_core, thriftport=50002, switch_config=config_core_mg, loglevel=LOG_LEVEL, cls=P4Switch, priority_queue_num=8)

    config_core_rj = os.path.join(path, "./sw_config/s3-commands.txt")
    sw_core_rj = rede.addSwitch("s3", netcfg=True, json=json_file_core, thriftport=50003, switch_config=config_core_rj, loglevel=LOG_LEVEL, cls=P4Switch, priority_queue_num=8)
        
    config_core_sp = os.path.join(path, "./sw_config/s4-commands.txt")
    sw_core_sp = rede.addSwitch("s4", netcfg=True, json=json_file_core, thriftport=50004, switch_config=config_core_sp, loglevel=LOG_LEVEL, cls=P4Switch, priority_queue_num=8)
    
    
    # Switches P4 edges
    path = os.path.dirname(os.path.abspath(__file__))
    json_file_edge = os.path.join(path, "p4/polka_edge.json")
    info(json_file_edge)
        
    config = os.path.join(path, "./sw_config/e1-vix-commands.txt")
    sw_edge_vix = rede.addSwitch("e1", netcfg=True, json=json_file_edge, thriftport=50101, switch_config=config, loglevel=LOG_LEVEL, cls=P4Switch, priority_queue_num=8)
    
    config = os.path.join(path, "./sw_config/e2-mg-commands.txt")
    sw_edge_mg = rede.addSwitch("e2", netcfg=True, json=json_file_edge, thriftport=50102, switch_config=config, loglevel=LOG_LEVEL, cls=P4Switch, priority_queue_num=8)

    config = os.path.join(path, "./sw_config/e3-rj-commands.txt")
    sw_edge_rj = rede.addSwitch("e3", netcfg=True, json=json_file_edge, thriftport=50103, switch_config=config, loglevel=LOG_LEVEL, cls=P4Switch, priority_queue_num=8)
    
    config = os.path.join(path, "./sw_config/e4-sp-commands.txt")
    sw_edge_sp = rede.addSwitch("e4", netcfg=True, json=json_file_edge, thriftport=50104, switch_config=config, loglevel=LOG_LEVEL, cls=P4Switch, priority_queue_num=8)
    
    # Criando os links
    info("#--- Criando os links ---#\n")
    # Links hosts to edge switches
    rede.addLink(host_vix, sw_edge_vix, bw=BW)
    rede.addLink(host_mg, sw_edge_mg, bw=BW)
    rede.addLink(host_rj, sw_edge_rj, bw=BW)
    rede.addLink(host_sp, sw_edge_sp, bw=BW)


    # Links edge switches to core switches
    rede.addLink(sw_edge_vix, sw_core_vix, bw=BW)
    rede.addLink(sw_edge_mg, sw_core_mg, bw=BW)
    rede.addLink(sw_edge_rj, sw_core_rj, bw=BW)
    rede.addLink(sw_edge_sp, sw_core_sp, bw=BW)
    
    # Links core switches
    rede.addLink(sw_core_vix, sw_core_mg, bw=BW)
    rede.addLink(sw_core_vix, sw_core_rj, bw=BW)
    rede.addLink(sw_core_mg, sw_core_rj, bw=BW)
    rede.addLink(sw_core_mg, sw_core_sp, bw=BW) 
    rede.addLink(sw_core_rj, sw_core_sp, bw=BW)   
    
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
    
    setLogLevel("info")
    remote_controller = False
    topologia(remote_controller)