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
    bit<16>   etherType;
    bit<9>    port;
    bit<3>    qid;
}

struct headers {
    ethernet_t  ethernet;
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
        meta.qid = 0;
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
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

    // Ação para encaminhar pacotes IPv4
    action ipv4_forward(bit<9> port, macAddr_t next_hop_mac) {
        // Define a porta de saída
        standard_metadata.egress_spec = port;
        
        // O MAC de origem passa a ser o MAC do roteador (que neste caso simplificado era o de destino original)
        //hdr.ethernet.srcAddr = hdr.ethernet.dstAddr; 
        
        // O MAC de destino passa a ser o do próximo salto (Next-Hop)
        //hdr.ethernet.dstAddr = next_hop_mac;         
        
        // Decrementa o Time To Live (TTL)
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;             
    }

    // Tabela de Roteamento (Longest Prefix Match)
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm; // Busca o IP de destino por maior prefixo
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    // --- AÇÃO DO CORE (CLASSIFICAÇÃO DE SLICE) ---
    action set_slice_class(bit<48> queue_id) {
        // Armazena temporariamente no qid para uso posterior
        meta.qid = (bit<3>)queue_id;
    }

    // NOVA TABELA: Classificação baseada no campo DiffServ (ToS)
    table core_slice_classifier {
        key = { 
            hdr.ipv4.diffserv: exact; // Faz o match exato no byte inteiro do DiffServ
        } 
        actions = { 
            set_slice_class; 
            drop; 
        }
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
       // Se o pacote for IPv4 válido e tiver TTL suficiente
        if (hdr.ipv4.isValid() && hdr.ipv4.ttl > 1) {
            ipv4_lpm.apply(); // Aplica a tabela de roteamento
        
            // 2º: O classificador lê o campo TOS (que pode ter acabado de ser alterado) e define a Fila
            core_slice_classifier.apply();

            if ( meta.qid == 1 ) {
                in_flow_id = 0;
            } else {
                in_flow_id = 1;
            }
            
        } else if (hdr.ipv4.isValid() && hdr.ipv4.ttl <= 1) {
            drop(); // Descarta se o pacote expirou
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
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
*********************** D E P A R S E R  *******************************
*************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

V1Switch( MyParser(), MyVerifyChecksum(), MyIngress(), MyEgress(), MyComputeChecksum(), MyDeparser() ) main;