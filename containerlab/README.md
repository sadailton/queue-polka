# Laboratório PORVIR

## Topologia

![Alt text](p4_programs/porvir/img/Topologia%20porvir.png)


### Subindo a topologia PORVIR

> [!NOTE]  
> Os comandos abaixo são executados dentro deste diretório

Subindo a topologia

```bash
$ containerlab deploy -t porvir.clab.yml
```

Configurando os hosts:
```bash
$ sudo ./p4_programs/porvir/config_hosts.sh
```
> [!NOTE]  
> Se o seu usuário não tiver permissão para executar o docker, use o sudo.

Configurando os swiches:

```bash
$ ./p4_programs/porvir/configura_edges.sh
```