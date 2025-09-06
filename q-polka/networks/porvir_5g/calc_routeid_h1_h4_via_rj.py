from polka.tools import calculate_routeid, print_poly, save_list2file
DEBUG = False


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
    
    print("From h1(vix) to h4(sp) ====")
    # defining the nodes from h1 (vix) to h4 (sp)
    nodes = [
        s[0], # s1 - vix
        s[2], # s3 - rj
        s[3]  # s4 - sp
    ]
    # defining the transmission state for each node from h1 to h2
    '''
    da esquerda para direita, os três primeiros bits identificam a porta de saída e os bits restantes
    identificam a fila dessa porta
    '''
    o = [
        [0, 1, 1, 1, 1, 1],  # s1 - vix porta 2, fila 7
        [1, 0, 0, 1, 1, 1],  # s3 - rj, porta 2, fila 7
        [0, 0, 1, 1, 1, 1]   # s4 - sp, porta 3, fila 7
    ]
    
    routeid = calculate_routeid(nodes, o, debug=DEBUG)
    routeIDs.append(routeid)
    print_poly(routeid)

    print("\nFrom h4(sp) to h1(vix) ====")
    # defining the nodes from h4 (sp) to h1 (vix)
    nodes = [
        s[3], # s4 - sp
        s[2], # s3 - rj
        s[0]  # s1 - vix
    ]
    
    # defining the transmission state for each node from h2 to h1
    o = [
        [0, 1, 1, 1, 1, 1],   # s4 - sp, porta 3, fila 7
        [0, 1, 0, 1, 1, 1],   # s3 - rj, porta 2, fila 7
        [0, 0, 1, 1, 1, 1]    # s1 - vix, porta 1, fila 7
    ]

    routeid = calculate_routeid(nodes, o, debug=DEBUG)
    routeIDs.append(routeid)
    print_poly(routeid)

    save_list2file("./routeIDs.txt", routeIDs)


if __name__ == '__main__':
    _main()