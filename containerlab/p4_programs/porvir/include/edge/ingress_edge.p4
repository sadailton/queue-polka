/***************** M A T C H - A C T I O N  *********************/
control Ingress(
    /* User */
    inout ingress_headers_t                       hdr,
    inout ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md) {


    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
#ifdef BYPASS_EGRESS
        ig_tm_md.bypass_egress = 1;
#endif      // BYPASS_EGRESS
    }

    apply {

        if (hdr.ipv4.isValid() && hdr.ethernet.etherType != TYPE_SRCROUTING) 
        {
            process_tunnel_encap.apply(hdr, meta, ig_intr_md, ig_prsr_md, ig_dprsr_md, ig_tm_md);
        
        } else if (hdr.ethernet.etherType == TYPE_SRCROUTING) 
        {
            hdr.ethernet.etherType = TYPE_IPV4;
            hdr.srcRoute.setInvalid();
            // this value is really hard-coded? (Yes)
            send(2);
        }
    }
}