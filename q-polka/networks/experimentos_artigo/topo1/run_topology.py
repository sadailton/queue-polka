from mininet.net import Mininet
from mininet.cli import CLI
from mininet.topo import Topo
from mininet_p4_queue import P4Switch
from mininet.log import setLogLevel, info
from mininet.link import TCLink
import os
from time import sleep
import controller


BW = 10 #Bandwidth
LOG_LEVEL="off" #info, debug, trace

def topologia(remote_controller):

    rede = Mininet(link=TCLink)
    
    #switches = []
    #edges = []
    
    host1_mac = "aa:00:00:00:00:01"
    host1_ip = "10.0.0.1/24"
    host1 = rede.addHost("h1", ip=host1_ip, mac = host1_mac)
    
    host2_mac = "aa:00:00:00:00:02"
    host2_ip = "10.0.0.2/24"
    host2 = rede.addHost("h2", ip=host2_ip, mac=host2_mac)
    
    host3_mac = "aa:00:00:00:00:03"
    host3_ip = "10.0.0.3/24"
    host3 = rede.addHost("h3", ip=host3_ip, mac=host3_mac)

    host4_mac = "aa:00:00:00:00:04"
    host4_ip = "10.0.0.4/24"
    host4 = rede.addHost("h4", ip=host4_ip, mac=host4_mac)

    hosts: list = [host1, host2, host3, host4]

    # Switches P4 core
    path = os.path.dirname(os.path.relpath(__file__))
    json_file_core = os.path.join(path, "./p4/polka_core.json")
    info(json_file_core + "\n")

    extern_module_path = "/home/p4/p4-tools/bmv2/targets/simple_switch/user_externs_WDRR"
    extern_module = "WDRR.so"
    wdrr_so = os.path.join(extern_module_path, extern_module)
    
    config_s1 = os.path.join(path, "./sw_config/s1-commands.txt")
    sw_core1 = rede.addSwitch("s1", netcfg=True, json=json_file_core, thriftport=52001, switch_config=config_s1, loglevel=LOG_LEVEL, cls=P4Switch, load_module=wdrr_so)
    
    config_s2 = os.path.join(path, "./sw_config/s2-commands.txt")
    sw_core2 = rede.addSwitch("s2", netcfg=True, json=json_file_core, thriftport=52002, switch_config=config_s2, loglevel=LOG_LEVEL, cls=P4Switch, load_module=wdrr_so)

    config_s3 = os.path.join(path, "./sw_config/s3-commands.txt")
    sw_core3 = rede.addSwitch("s3", netcfg=True, json=json_file_core, thriftport=52003, switch_config=config_s3, loglevel=LOG_LEVEL, cls=P4Switch, load_module=wdrr_so)
        
    config_s4 = os.path.join(path, "./sw_config/s4-commands.txt")
    sw_core4 = rede.addSwitch("s4", netcfg=True, json=json_file_core, thriftport=52004, switch_config=config_s4, loglevel=LOG_LEVEL, cls=P4Switch, load_module=wdrr_so)
    
    
    # Switches P4 edges
    path = os.path.dirname(os.path.abspath(__file__))
    json_file_edge = os.path.join(path, "p4/polka_edge.json")
    info(json_file_edge + "\n")
        
    config_e1 = os.path.join(path, "./sw_config/e1-commands.txt")
    sw_edge1 = rede.addSwitch("e1", netcfg=True, json=json_file_edge, thriftport=52101, switch_config=config_e1, loglevel=LOG_LEVEL, cls=P4Switch, load_module=wdrr_so)
    
    config_e2 = os.path.join(path, "./sw_config/e2-commands.txt")
    sw_edge2 = rede.addSwitch("e2", netcfg=True, json=json_file_edge, thriftport=52102, switch_config=config_e2, loglevel=LOG_LEVEL, cls=P4Switch, load_module=wdrr_so)
    
    config_e3 = os.path.join(path, "./sw_config/e3-commands.txt")
    sw_edge3 = rede.addSwitch("e3", netcfg=True, json=json_file_edge, thriftport=52103, switch_config=config_e3, loglevel=LOG_LEVEL, cls=P4Switch, load_module=wdrr_so)

    config_e4 = os.path.join(path, "./sw_config/e4-commands.txt")
    sw_edge4 = rede.addSwitch("e4", netcfg=True, json=json_file_edge, thriftport=52104, switch_config=config_e4, loglevel=LOG_LEVEL, cls=P4Switch, load_module=wdrr_so)
    
    switches: list = [sw_core1, sw_core2, sw_core3, sw_core4, sw_edge1, sw_edge2, sw_edge3, sw_edge4]

    # Criando os links
    info("#--- Criando os links ---#\n")
    # Links hosts to edge switches
    rede.addLink(host1, sw_edge1)
    rede.addLink(host2, sw_edge2)
    rede.addLink(host3, sw_edge3)
    rede.addLink(host4, sw_edge4)

    # Links core switches to edge switches
    rede.addLink(sw_core1, sw_edge2)
    rede.addLink(sw_core1, sw_edge1)
    rede.addLink(sw_core2, sw_edge3)
    rede.addLink(sw_core2, sw_edge1)

    rede.addLink(sw_core3, sw_edge4)
    rede.addLink(sw_core4, sw_edge4)

    rede.addLink(sw_core1, sw_core3)
    rede.addLink(sw_core2, sw_core4)
    
    info("#--- Iniciando a rede ---#\n")
    rede.start()
    rede.staticArp()

    # disabling offload for rx and tx on each host interface
    for host in hosts:
        host.cmd("ethtool --offload {}-eth0 rx off tx off".format(host.name))
        host.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
        host.cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")

    for sw in switches:
        sw.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
        sw.cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")
        sw.cmd("sysctl -w net.ipv6.conf.lo.disable_ipv6=1")

    h1 = rede.get("h1")
    h2 = rede.get("h2")
    h3 = rede.get("h3")
    h4 = rede.get("h4")

    h1.cmd("arp -s 10.0.0.2 aa:00:00:00:00:02")
    h1.cmd("arp -s 10.0.0.3 aa:00:00:00:00:03")
    h1.cmd("arp -s 10.0.0.4 aa:00:00:00:00:04")
    h2.cmd("arp -s 10.0.0.1 aa:00:00:00:00:01")
    h2.cmd("arp -s 10.0.0.3 aa:00:00:00:00:03")
    h2.cmd("arp -s 10.0.0.4 aa:00:00:00:00:04")
    h3.cmd("arp -s 10.0.0.1 aa:00:00:00:00:01")
    h3.cmd("arp -s 10.0.0.2 aa:00:00:00:00:02")
    h3.cmd("arp -s 10.0.0.4 aa:00:00:00:00:04")
    h4.cmd("arp -s 10.0.0.1 aa:00:00:00:00:01")
    h4.cmd("arp -s 10.0.0.2 aa:00:00:00:00:02")
    h4.cmd("arp -s 10.0.0.3 aa:00:00:00:00:03")

    # Configurando os hosts para enviar tráfego
    '''
    h4.cmd("python3 ./iperf_test.py &")
    sleep(1)
    h1.cmd("python3 ./iperf_test.py &")
    sleep(60)
    h2.cmd("python3 ./iperf_test.py &")
    sleep(60)
    h3.cmd("python3 ./iperf_test.py &")
    sleep(90)
    controller.altera_caminho_sem_menu(opcao_menu=1) # altera o caminho do h1 para s1-s3 na fila 1
    '''
    info("*** Running CLI\n")
    CLI(rede)

    os.system("pkill -9 -f 'xterm'")

    info("*** Stopping network\n")
    rede.stop()
    
if __name__ == "__main__":
    
    setLogLevel("info")
    remote_controller = False
    topologia(remote_controller)