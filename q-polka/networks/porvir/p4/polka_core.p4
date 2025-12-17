/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
*********************** T Y P E D E F S  ********************************
*************************************************************************/
// Definimos tipos fortes para "amarrar" o template do Extern
typedef bit<48> rank_t;
typedef bit<1>  flag_t;

// ============================================================================
// DEFINIÇÃO DO EXTERN (COM TEMPLATES)
// ============================================================================
extern DR_PIFO_scheduler<T1,T2> {
    DR_PIFO_scheduler(flag_t verbose); 
    
    void my_scheduler(
        in T1 in_flow_id, 
        in T1 number_of_levels_used, 
        in T1 in_pred, 
        in T1 in_arrival_time, 
        in T2 in_shaping, 
        in T2 in_enq, 
        in T1 in_pkt_ptr, 
        in T2 in_deq, 
        in T2 in_use_updated_rank, 
        in T2 in_force_deq, 
        in T1 in_force_deq_flow_id, 
        in T2 in_enable_error_correction, 
        in T2 reset_time
    );

    void pass_rank_values ( 
        in T1 rank_value, 
        in T1 level_id
    );

    void pass_updated_rank_values ( 
        in T1 rank_value, 
        in T1 flow_id, 
        in T1 level_id
    );
}

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_SRCROUTING = 0x1234;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header srcRoute_t {
    bit<160>   routeId;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<6>    diffserv; 
    bit<2>    ecn;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
    bit<32>   options; 
}

struct metadata {
    // Metadados do Polka
    bit<160>  routeId;
    bit<16>   etherType;
    bit<32>   poly;       
    bit<1>    apply_sr;   
    bit<14>   port;       
    bit<8>    qid;        
    
    // Metadados auxiliares para DR-PIFO
    bit<48>   dr_pifo_rank; 
}

struct headers {
    ethernet_t   ethernet;
    srcRoute_t   srcRoute; 
    ipv4_t       ipv4;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        meta.etherType = hdr.ethernet.etherType;
        transition select(hdr.ethernet.etherType) {
            TYPE_SRCROUTING: parse_srcRouting;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_srcRouting {
        packet.extract(hdr.srcRoute);
        meta.routeId = hdr.srcRoute.routeId;
        transition select(hdr.srcRoute.routeId[159:156]) { 
             4: parse_ipv4; 
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

    // =================================================================
    // 1. INSTANCIAÇÃO USANDO TYPEDEFS E CAST NO CONSTRUTOR
    // =================================================================
    // O construtor recebe (flag_t)1 que é constante de tempo de compilação.
    @userextern @name("my_DR_PIFO")
    DR_PIFO_scheduler<rank_t, flag_t>((flag_t)1) my_DR_PIFO;

    // Todas as variáveis declaradas explicitamente com rank_t e flag_t
    rank_t level_3_rank;
    rank_t in_pred = 15;
    rank_t in_pkt_ptr;
    rank_t in_force_deq_flow_id = 0;
    rank_t new_rank_flow_id = 0;
    rank_t flow_new_rank = 0;
    rank_t number_of_levels_used = 1;
    
    // Variável para "Zero" usando o typedef
    rank_t ZERO_RANK = 0; 

    flag_t in_shaping = 1;
    flag_t in_enq = 1;
    flag_t in_deq = 0;
    flag_t in_use_updated_rank = 1;
    flag_t in_force_deq = 0;
    flag_t in_enable_error_correction = 1;
    flag_t update_flow_rank = 0;
    flag_t reset_time = 0;

    register<bit<48>>(1) register_last_ptr;
    register<bit<48>>(1) lowest_rank;
    register<bit<48>>(1) lowest_rank_flow_id;
    register<bit<48>>(1024) flows_min_rank;
    
    rank_t in_flow_id = 0;

    action assign_flow_id(rank_t flow_id) {
        in_flow_id = flow_id;
    }

    table lookup_flow_id {
        key = {
            hdr.ipv4.srcAddr: lpm;
        }
        actions = {
            assign_flow_id;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action crc16_lookUp(bit<32> poly) {
        meta.poly = poly;
    }

    table crc_table {
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
            crc16_lookUp;
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    action srcRoute_nhop(bit<14> port, bit<8> qid) {
        meta.port = port;
        meta.qid = qid; 
        meta.apply_sr = 1;
    }

    table nhop_table {
        key = {
            meta.routeId: exact; 
        }
        actions = {
            srcRoute_nhop;
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    apply {
        meta.apply_sr = 0;

        if (hdr.srcRoute.isValid()) {
             crc_table.apply();
             nhop_table.apply(); 
        }

        if (meta.apply_sr == 1) {
            
            standard_metadata.egress_spec = (bit<9>)meta.port;

            if (hdr.ipv4.isValid()) {
                lookup_flow_id.apply();
            }

            register_last_ptr.read(in_pkt_ptr, 0);
            in_pkt_ptr = in_pkt_ptr + (rank_t)(1);
            register_last_ptr.write(0, in_pkt_ptr);

            // Cast seguro para o tipo rank_t
            level_3_rank = (rank_t)meta.qid;

            flows_min_rank.read(meta.dr_pifo_rank, (bit<32>)in_flow_id); 

            if((meta.dr_pifo_rank == 0) || (level_3_rank < meta.dr_pifo_rank)) {
                meta.dr_pifo_rank = level_3_rank;
                new_rank_flow_id = in_flow_id;
                flow_new_rank = level_3_rank;
                update_flow_rank = 1;
                flows_min_rank.write((bit<32>)in_flow_id, level_3_rank);
            }

            reset_time = 0;

            bit<48> lowest_rank_value;
            lowest_rank.read(lowest_rank_value, 0);
            
            if((lowest_rank_value > level_3_rank) || (lowest_rank_value == 0)) {
                lowest_rank_value = level_3_rank;
                lowest_rank.write(0, lowest_rank_value);
                in_force_deq = 1;
                in_force_deq_flow_id = in_flow_id;
                lowest_rank_flow_id.write(0, in_flow_id);
            } else if (lowest_rank_value != 0) {
                in_force_deq = 1;
                lowest_rank_flow_id.read(in_force_deq_flow_id, 0);
            }

            // Usamos ZERO_RANK (tipo rank_t) que casa exatamente com T1
            my_DR_PIFO.pass_rank_values(level_3_rank, ZERO_RANK);
            
            if(update_flow_rank == 1) {
                my_DR_PIFO.pass_updated_rank_values(flow_new_rank, new_rank_flow_id, ZERO_RANK);
            }

            in_force_deq = 0; 

            // Todas as variáveis aqui são do tipo rank_t ou flag_t
            my_DR_PIFO.my_scheduler(
                in_flow_id, 
                number_of_levels_used, 
                in_pred, 
                in_pkt_ptr, 
                in_shaping, 
                in_enq, 
                in_pkt_ptr, 
                in_deq, 
                in_use_updated_rank, 
                in_force_deq, 
                in_force_deq_flow_id, 
                in_enable_error_correction, 
                reset_time
            );

        } else {
            drop();
        }
    }
}

/*************************************************************************
**************** E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
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
              hdr.ipv4.ecn,
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
        packet.emit(hdr.srcRoute); 
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
*********************** S W I T C H  *******************************
*************************************************************************/

V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;