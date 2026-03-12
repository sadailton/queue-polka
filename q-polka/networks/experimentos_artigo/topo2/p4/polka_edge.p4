/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/**
Código otimizado para o edge do POLKA. Este código extrai o id da porta
e da fila do routeID.
**/

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

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

//typedef bit<9>  egressSpec_t;
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
    bit<160>  routeId;
    bit<16>   etherType;
    bit<1>    apply_sr;
    bit<9>    port;
    bit<3>    qid;
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
************ C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
************** I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    // --- AÇÕES COMUNS ---
    action drop() {
        mark_to_drop(standard_metadata);
    }
    
    // --- AÇÕES DO EDGE (ENCAP & NHOP) ---
    action add_sourcerouting_header(bit<9> egress_port, bit<1> sr, macAddr_t dmac, bit<160> routeIdPacket) {
        meta.port = egress_port;
        meta.apply_sr = sr;
        meta.routeId = routeIdPacket;
        hdr.ethernet.dstAddr = dmac;
        hdr.srcRoute.setValid();
        hdr.srcRoute.routeId = routeIdPacket;
    }

    action srcRoute_nhop() {
        bit<16> nresult;
        bit<160> ndata = meta.routeId >> 16;
        bit<16> dif = (bit<16>)meta.routeId;

        hash(nresult, HashAlgorithm.crc16_custom, 16w0, {ndata}, 64w8589934592);
        bit<16> nlabel = nresult ^ dif;

        meta.port = (bit<9>)nlabel[11:3]; // 11-3 = 8 bits para porta
        meta.qid  = (bit<3>)nlabel[2:0]; // 2-0 = 3 bits para qid
    }

    // --- AÇÃO DO CORE (CLASSIFICAÇÃO DE SLICE) ---
    action set_slice_class(bit<48> flow_id) {
        // Armazena temporariamente no qid para uso posterior
        meta.qid = (bit<3>)flow_id; 
    }

    // --- TABELAS ---
    table tunnel_encap_process_sr {
        key = { hdr.ipv4.dstAddr: lpm; }
        actions = { add_sourcerouting_header; drop; }
        size = 1024;
        default_action = drop();
    }

    // NOVA TABELA: Substitui os RouteIDs "chumbados" no código
    table core_slice_classifier {
        key = { meta.routeId: exact; } 
        actions = { set_slice_class; drop; }
        size = 256;
        default_action = set_slice_class(2); // Default para Fila 2 (Best Effort)
    }

    // --- EXTERNS WDRR ---
    @userextern @name("my_hier")
    hier_scheduler<bit<48>,bit<1>>(1) my_hier;
    register<bit<48>>(1) register_last_ptr;

    // --- VARIÁVEIS ---
    bit<48> in_pkt_ptr;
    bit<48> in_flow_id = 1;

    apply {
        if (hdr.ipv4.isValid() && hdr.ethernet.etherType != TYPE_SRCROUTING) {
            
            // 1. LÓGICA DE BORDA (EDGE INGRESS)

            if(tunnel_encap_process_sr.apply().hit) {
            
                if (meta.apply_sr == 1) {
                    hdr.ethernet.etherType = TYPE_SRCROUTING;
                    srcRoute_nhop();
                } else {
                    hdr.srcRoute.setInvalid();
                    in_flow_id = 1; // Default para Fila 2 (Best Effort)
                }
                // Proteção contra Underflow de bit
               if ( meta.qid == 1 ) {
                    in_flow_id = 0;
               } else  {
                    in_flow_id = 1;
               }
                
                standard_metadata.egress_spec = meta.port;
            } else { drop(); }
        } else if (hdr.ethernet.etherType == TYPE_SRCROUTING) {
            
                    // 2. LÓGICA DE NÚCLEO / SAÍDA (CORE EGRESS)
                    hdr.ethernet.etherType = TYPE_IPV4;
                    hdr.srcRoute.setInvalid();
                    standard_metadata.egress_spec = 1; // HARDCODED: Redireciona para porta 1
                    
                    // Aplica a tabela dinâmica em vez do IF hardcoded
                    core_slice_classifier.apply();
                    in_flow_id = (bit<48>)meta.qid - 1;
                }

        // 3. INTEGRAÇÃO COM WDRR (C++)
        
        // Verifica se o pacote sofreu mark_to_drop (Porta 511 no BMv2)
        if (standard_metadata.egress_spec != 511) {
            
            register_last_ptr.read(in_pkt_ptr, 0);
            in_pkt_ptr = in_pkt_ptr + 1;
            register_last_ptr.write(0, in_pkt_ptr);    
            
            // Passa os valores diretos economizando declaração de variáveis inúteis
            my_hier.pass_rank_values((bit<48>)standard_metadata.packet_length, 0);
            
            // Chamada do escalonador enviando constantes (0 e 1) no lugar de variáveis
            my_hier.my_scheduler(
                in_flow_id, 
                1,          // number_of_levels_used
                0,          // in_pred
                in_pkt_ptr, // in_arrival_time
                0,          // in_shaping
                1,          // in_enq
                in_pkt_ptr, // in_pkt_ptr
                0,          // in_deq
                0           // reset_time
            );
        }
    }
}

/*************************************************************************
**************** E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/
control MyEgress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
************* C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
*********************** D E P A R S E R  *******************************
*************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.srcRoute);
        packet.emit(hdr.ipv4);
    }
}

V1Switch( MyParser(), MyVerifyChecksum(), MyIngress(), MyEgress(), MyComputeChecksum(), MyDeparser() ) main;