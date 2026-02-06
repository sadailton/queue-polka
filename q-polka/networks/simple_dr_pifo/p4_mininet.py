# p4_mininet.py
from mininet.net import Mininet
from mininet.node import Switch, Host
from mininet.log import setLogLevel, info, error
from mininet.moduledeps import pathCheck
from sys import exit
import os
import tempfile
import socket

class P4Host(Host):
    def config(self, **params):
        r = super(Host, self).config(**params)
        # Desativa offloading para evitar problemas com pacotes P4
        for off in ["rx", "tx", "sg"]:
            cmd = "/sbin/ethtool --offload %s %s off" % (self.defaultIntf(), off)
            self.cmd(cmd)
        # Desativa checksum offloading do IPv6 para evitar erros
        self.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
        self.cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")
        self.cmd("sysctl -w net.ipv6.conf.lo.disable_ipv6=1")
        return r

class P4Switch(Switch):
    """P4 Switch para Mininet usando simple_switch"""
    device_id = 0

    def __init__(self, name, sw_path = None, json_path = None,
                 thrift_port = None, pcap_dump = False,
                 log_console = True, verbose = False, device_id = None,
                 enable_debugger = False, **kwargs):
        Switch.__init__(self, name, **kwargs)
        assert(sw_path)
        assert(json_path)
        # Verify that the switch binary exists
        if not os.path.isfile(sw_path):
            error("Invalid switch path: %s\n" % sw_path)
            exit(1)
        self.sw_path = sw_path
        # Verify that the P4 JSON file exists
        if not os.path.isfile(json_path):
            error("Invalid JSON path: %s\n" % json_path)
            exit(1)
        self.json_path = json_path
        self.verbose = verbose
        logfile = '/tmp/p4s.{}.log'.format(self.name)
        self.output = open(logfile, 'w')
        self.thrift_port = thrift_port
        if self.thrift_port is None:
             self.thrift_port = P4Switch.device_id + 9090
        if device_id is not None:
            self.device_id = device_id
            P4Switch.device_id = max(P4Switch.device_id, device_id)
        else:
            self.device_id = P4Switch.device_id
            P4Switch.device_id += 1
        self.nanomsg = "ipc:///tmp/bm-{}-log.ipc".format(self.device_id)
        self.enable_debugger = enable_debugger
        self.pcap_dump = pcap_dump
        self.log_console = log_console

    @classmethod
    def setup(cls):
        pass

    def check_switch_started(self, pid):
        """While the process is running (pid exists), we check if the Thrift
        server has been started. If the Thrift server is ready, we assume that
        the switch was started successfully. This is only reliable if the Thrift
        server is started at the end of the init process"""
        import time
        import socket
        while True:
            if not os.path.exists("/proc/%d" % pid):
                return False
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.5)
            result = sock.connect_ex(('localhost', self.thrift_port))
            if result == 0:
                return  True
            sock.close()
            time.sleep(0.5)

    def start(self, controllers):
        "Start up a new P4 switch"
        info("Starting P4 switch {}.\n".format(self.name))
        args = [self.sw_path]
        for port, intf in self.intfs.items():
            if not intf.IP():
                args.extend(['-i', str(port) + "@" + intf.name])
        if self.pcap_dump:
            args.append("--pcap")
            # args.append("--useFiles")
        if self.thrift_port:
            args.extend(['--thrift-port', str(self.thrift_port)])
        if self.nanomsg:
            args.extend(['--nanolog', self.nanomsg])
        args.extend(['--device-id', str(self.device_id)])
        P4Switch.device_id += 1
        args.append(self.json_path)
        if self.enable_debugger:
            args.append("--debugger")
        if self.log_console:
            #args.append("--log-console")
            args.append("--log-file /tmp/p4s.log")
        args.append("-L trace")
        args.append("-- --load-module=/home/p4/p4-tools/bmv2/targets/simple_switch/user_externs_dr_pifo/DR_PIFO.so")
        args.append("--priority-queues 32")
        
        info(' '.join(args) + "\n")
        
        # Executa o switch em segundo plano
        self.cmd(' '.join(args) + ' > /dev/null 2>&1 &')
        
        # Aguarda o switch iniciar
        pid = int(self.cmd('echo $!'))
        if self.check_switch_started(pid):
             info("P4 switch {} has been started.\n".format(self.name))
        else:
             error("P4 switch {} did not start correctly.\n".format(self.name))
             exit(1)

    def stop(self):
        "Terminate P4 switch."
        self.output.flush()
        self.cmd('kill %' + self.sw_path)
        self.cmd('wait')
        self.deleteIntfs()