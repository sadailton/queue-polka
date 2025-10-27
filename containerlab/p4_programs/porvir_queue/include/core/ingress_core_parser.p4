/***********************  P A R S E R  **************************/
parser IngressParser(packet_in        packet,
    /* User */
    out ingress_headers_t          hdr,
    out ingress_metadata_t         meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t  ig_intr_md)
{

    //TofinoIngressParser() tofino_parser;

    /*state start {
        tofino_parser.apply(pkt, ig_intr_md);
        transition verify_ethernet;
    }*/
    
    state start {
        // Mandatory code required by Tofino Architecture 
        packet.extract(ig_intr_md);
        packet.advance(PORT_METADATA_SIZE);
        transition init_meta;
    }

    state init_meta {
        meta.routeId = 0;
        meta.etherType = 0;
        meta.apply_sr = 0;
        meta.apply_decap = 0;
        meta.port = 0;
        meta.queue_id = 0;
        meta.hash_result = 0;
        
        
        transition verify_ethernet;
    }

   state verify_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            //TYPE_IPV4: parse_ipv4;
            TYPE_SRCROUTING: parse_srcRouting;
            default: accept;
        }
    }

    state parse_srcRouting {
        packet.extract(hdr.srcRoute);
        meta.apply_sr = 1;
        meta.routeId = hdr.srcRoute.routeId;
        transition accept;
    }
}