/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/**
Problema: Ao pingar do h1 para o h4, o pacote chega corretamente até o edge4, porém
o calculo do routeID para extrair a porta de saída está dando um valor errado. No 
teste feito no dia 09\/03\/2026 o valor da porta de saída no edge4 é de 489.

O mesmo acontece ao pingar do h4 para o h1 mas na ordem inversa.
 */

extern hier_scheduler<T1,T2> {
    hier_scheduler(bit<1> verbose); 
    void my_scheduler(in T1 in_flow_id, in T1 number_of_levels_used, in T1 in_pred, in T1 in_arrival_time, in T2 in_shaping, in T2 in_enq, in T1 in_pkt_ptr, in T2 in_deq, in T2 reset_time);
    void pass_rank_values ( in T1 rank_value, in T1 level_id);
    void pass_updated_rank_values ( in T1 rank_value, in T1 flow_id, in T1 level_id);
}

extern floor_extern<T1> {
   	floor_extern(bit<1> verbose2); 
    void floor ( in T1 nom, in T1 dom, inout T1 result);
}

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_SRCROUTING = 0x1234;


//Ethernet frame payload padding and P4
//https://github.com/p4lang/p4-spec/issues/587

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header srcRoute_t {
    bit<160>    routeId;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

struct metadata {
    bit<160>   routeId;
    bit<16>   etherType;
    bit<1> apply_sr;
    bit<9> port;
    bit<3> qid;
}

struct polka_t_top {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
    bit<160>    routeId;
}

struct headers {
    ethernet_t  ethernet;
    srcRoute_t  srcRoute;
    ipv4_t      ipv4;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        meta.apply_sr = 0;
        meta.routeId = 0;
        meta.port = 0;
        meta.qid = 0;
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            TYPE_SRCROUTING: parse_srcRouting;
            default: accept;
        }
    }

    state parse_srcRouting {
        packet.extract(hdr.srcRoute);
        meta.routeId = hdr.srcRoute.routeId;
        transition accept;
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }


}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}



/*************************************************************************
**********************  T U N N E L   E N C A P   ************************
*************************************************************************/
control process_tunnel_encap(inout headers hdr,
                            inout metadata meta,
                            inout standard_metadata_t standard_metadata) {
    action tdrop() {
        mark_to_drop(standard_metadata);
    }

    action add_sourcerouting_header (egressSpec_t port, bit<1> sr, macAddr_t dmac, bit<160>  routeIdPacket){

        meta.apply_sr = sr;
        meta.routeId = routeIdPacket;

        hdr.ethernet.dstAddr = dmac;

        hdr.srcRoute.setValid();
        hdr.srcRoute.routeId = routeIdPacket;

    }

    table tunnel_encap_process_sr {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            add_sourcerouting_header;
            tdrop;
        }
        size = 1024;
        default_action = tdrop();
    }

    apply {

        tunnel_encap_process_sr.apply();

        if (meta.apply_sr!=1) {
            
            hdr.srcRoute.setInvalid();

        } else {

            hdr.ethernet.etherType = TYPE_SRCROUTING;
        }
    }
}

/*control process_queue_selection(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {

    action tdrop() {
        mark_to_drop(standard_metadata);
    }

    action set_queue(bit<3> qid) {
        meta.qid = qid;
    }

    table queue_select {
        key = {
            hdr.ipv4.diffserv: exact;
        }
        actions = {
            set_queue;
            tdrop;
        }
        size = 1024;
        default_action = tdrop();
    }
    apply { queue_select.apply(); }
}*/

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action drop() {
        mark_to_drop(standard_metadata);
    }
    
    action srcRoute_nhop() {
        bit<16> nresult;

        // 1. ndata é o deslocamento de 16 bits
        bit<160> ndata = meta.routeId >> 16;
        
        // 2. OTIMIZAÇÃO: dif é apenas a extração dos 16 bits menos significativos.
        // O P4 faz o truncamento automático ao fazer o cast, não precisa do XOR e Shift.
        bit<16> dif = (bit<16>)meta.routeId;

        // 3. OTIMIZAÇÃO: Passar as constantes diretamente economiza alocação de variáveis.
        hash(nresult,
             HashAlgorithm.crc16_custom,
             16w0,          // nbase
             {ndata}, 
             64w8589934592); // ncount (4294967296 * 2)

        // 4. Cálculo do rótulo
        bit<16> nlabel = nresult ^ dif;

        // 5. OTIMIZAÇÃO: Extração direta usando bit slicing (fatiamento).
        // Removemos o "nport = nresult ^ dif;" que era código morto (sobrescrito logo em seguida).
        meta.port = (bit<9>)nlabel[11:3]; // Pega do bit 3 ao 11 e joga na porta
        meta.qid  = (bit<3>)nlabel[2:0];  // Pega do bit 0 ao 2 (equivale ao seu >> 13 e & 0x7)

    }

    @userextern @name("my_hier")
    hier_scheduler<bit<48>,bit<1>>(1) my_hier;

    //@userextern @name("floor_extern_obj")
    //floor_extern<bit<48>>(1) floor_extern_obj;

    bit <48> level_0_rank; //valor a ser descontado do credito do fluxo
    //bit <48> in_pred= 200000;
    bit <48> in_pred = 0;
    bit <48> in_pkt_ptr;
    //bit <48> out_pkt_ptr=0;
    bit <48> number_of_levels_used = 1;

    bit <1> in_shaping = 0;
    bit <1> in_enq = 1;
    bit <1> in_deq = 0;
    bit <1> reset_time = 0;

    register<bit<48>>(1) register_last_ptr;

    bit <48> in_flow_id = 2;

    apply {

    	if (hdr.ipv4.isValid() && hdr.ethernet.etherType != TYPE_SRCROUTING) {
            
            process_tunnel_encap.apply(hdr, meta, standard_metadata);
            srcRoute_nhop();
            //process_queue_selection.apply(hdr, meta, standard_metadata);
            standard_metadata.egress_spec = meta.port;
            in_flow_id = (bit<48>)meta.qid - 1;

        } else if (hdr.ethernet.etherType == TYPE_SRCROUTING) {

            meta.routeId = hdr.srcRoute.routeId;
            //register_routeid.write(0,hdr.srcRoute.routeId);
            srcRoute_nhop();
            hdr.ethernet.etherType = TYPE_IPV4;
            hdr.srcRoute.setInvalid();
            standard_metadata.egress_spec = meta.port;
            in_flow_id = (bit<48>)meta.qid - 1;
        
		}

        if((in_flow_id > 3) || (in_flow_id < 0))
        {
            in_flow_id = 1;      
        }
        else
        {
            register_last_ptr.read(in_pkt_ptr,0);
            in_pkt_ptr = in_pkt_ptr + (bit<48>)(1);
            register_last_ptr.write(0,in_pkt_ptr);    
            
            reset_time = 0;

            level_0_rank = (bit<48>)standard_metadata.packet_length;

            my_hier.pass_rank_values(level_0_rank,0);
            
            //in_flow_id = in_flow_id - 1;

            /*if (in_flow_id > 0)
                in_flow_id = in_flow_id - 1; //Esse valor é usado como índice de um vetor no TM.*/

            my_hier.my_scheduler(in_flow_id, number_of_levels_used, in_pred, in_pkt_ptr, in_shaping, in_enq, in_pkt_ptr, in_deq, reset_time);
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
                    
    apply { }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
    apply {   }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.srcRoute);
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;