from polka.tools import calculate_routeid, print_poly, save_list2file
DEBUG = False

## H3 -> S3(RJ) -> S4(SP) -> H4

def _main():
    
    routeIDs: list = []
    
    print("Insering irred poly (node-ID)")
    s = [
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1],  # s1 - vix
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1],  # s2 - mg
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1],  # s3 - rj
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1]   # s4 - sp
    ]
    '''
    s = [
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0]
    ]'''
    
    print("From h3(rj) to h4(sp) ====")
    # defining the nodes from h3 (rj) to h4 sp)
    nodes = [
        s[2], # s3 - rj
        s[3], # s4 - sp
    ]
    # defining the transmission state for each node from h3 to h4
    '''
    da esquerda para direita, os três primeiros bits identificam a porta de saída e os bits restantes
    identificam a fila dessa porta
    '''
    o = [
        [1, 0, 0, 0, 0, 1],  # s3 - rj porta 4, fila 1
        [0, 0, 1, 0, 1, 1],  # s4 - sp, porta 1, fila 3
    ]
    
    routeid = calculate_routeid(nodes, o, debug=DEBUG)
    routeIDs.append(routeid)
    print_poly(routeid)

    print("\nFrom h4(sp) to h3(rj) ====")
    # defining the nodes from h4 (sp) to h3 (rj)
    nodes = [
        s[3], # s4 - mg
        s[2]  # s3 - rj
    ]
    
    # defining the transmission state for each node from h4 to h3
    o = [
        [0, 1, 1, 0, 1, 1],   # s4 - sp
        [0, 0, 1, 0, 0, 1]    # s3 - rj
    ]

    routeid = calculate_routeid(nodes, o, debug=DEBUG)
    routeIDs.append(routeid)
    print_poly(routeid)

    save_list2file("./routeIDs.txt", routeIDs)


if __name__ == '__main__':
    _main()