from polka.tools import calculate_routeid, print_poly, save_list2file
DEBUG = False


def _main():
    
    routeIDs: list = []
    
    print("Insering irred poly (node-ID)")
    s = [
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1],  # s1 - 0
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1],  # s2 - 1
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1],  # s3 - 2
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1],  # s4 - 3
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1],  # e1 - 4
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1],  # e2 - 5
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1],  # e3 - 6
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1],  # e4 - 7
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1],  # e5 - 8
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 1]   # e6 - 9
    ]
    
    print("=== IDA ===")
    # defining the nodes from h1 (vix) to h2 (mg)
    nodes = [
        s[5],
        s[0],
        s[2],
        s[7],
    ]
    # defining the transmission state for each node from h1 to h2
    '''
    da esquerda para direita, os três primeiros bits identificam a porta de saída e os bits restantes
    identificam a fila dessa porta
    '''
    output_fila1: list = []
    output_fila2: list = []
    output_fila1 = [
        [0, 1, 0, 0, 0, 1],
        [0, 1, 1, 0, 0, 1],
        [0, 0, 1, 0, 0, 1],
        [0, 0, 1, 0, 0, 1],
    ]   

    output_fila2 = [
        [0, 1, 0, 0, 1, 0],
        [0, 1, 1, 0, 1, 0],
        [0, 0, 1, 0, 1, 0],
        [0, 0, 1, 0, 1, 0],
    ]

    o = output_fila2
    
    routeid = calculate_routeid(nodes, o, debug=DEBUG)
    routeIDs.append(routeid)
    print_poly(routeid)

    print("\n=== VOLTA ===")
    # defining the nodes from h2 (mg) to h1 (vix)
    nodes = [
        s[7],
        s[2],
        s[0],
        s[5],
    ]

    # defining the transmission state for each node from h2 to h1
    output_fila1 = [
        [0, 1, 0, 0, 0, 1],
        [0, 1, 1, 0, 0, 1],
        [0, 0, 1, 0, 0, 1],
        [0, 0, 1, 0, 0, 1],
    ]   

    output_fila2 = [
        [0, 1, 0, 0, 1, 0],
        [0, 1, 1, 0, 1, 0],
        [0, 0, 1, 0, 1, 0],
        [0, 0, 1, 0, 1, 0],
    ]

    o = output_fila2

    routeid = calculate_routeid(nodes, o, debug=DEBUG)
    routeIDs.append(routeid)
    print_poly(routeid)

    save_list2file("./routeIDs.txt", routeIDs)


if __name__ == '__main__':
    _main()