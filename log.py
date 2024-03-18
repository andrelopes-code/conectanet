import re
import sys

PATTERN = re.compile(r"""
(IN=(?P<in>\w*))                                  
.*                                                
(OUT=(?P<out>\w*))                              
.*                                                
(SRC=(?P<src>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}))  
.*                                                
(DST=(?P<dst>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}))  
.*                                             
(PROTO=(?P<proto>\w*))
.*
(SPT=(?P<sport>\d*))
.*
(DPT=(?P<dport>\d*))
""", re.VERBOSE)


def monitorar_arquivo_log(nome_arquivo, full_file):
    try:
        with open(nome_arquivo, 'r') as arquivo:
            if full_file is False:
                arquivo.seek(0, 2)
            while True:
                linha = arquivo.readline()
                if not linha or not "iptables-denied:" in linha:
                    continue
                
                match = PATTERN.search(linha)
                
                if match:
                    DIA = linha[4:6]
                    MES = linha[0:3]
                    HORA = linha[7:15]
                    IN = PATTERN.search(linha).group('in')
                    OUT = PATTERN.search(linha).group('out')
                    SRC = PATTERN.search(linha).group('src')
                    DST = PATTERN.search(linha).group('dst')
                    PROTO = PATTERN.search(linha).group('proto')
                    SPT = PATTERN.search(linha).group('sport')
                    DPT = PATTERN.search(linha).group('dport')
                else:
                    continue
                sentido = "\033[1;32mINP ->\033[m" if IN else "\033[1;31mOUT ->\033[m"
                iface = IN or OUT
                
                print(
"""\033[1;31m[DROPED]   \033[1;35m{} {} \033[m[\033[1;35m{}\033[0m] - - - - \033[1;32m{} \033[m(\033[1;36m{}\033[0m) - \
\033[1;31m== \033[1;33m{}\033[1;31m =>\033[m - \033[1;32m{} \033[m(\033[1;36m{}\033[0m) - - \
{} \033[1;33m{}\033[0m""".format(DIA, MES, HORA, SRC, SPT, PROTO, DST, DPT, sentido, iface))

            
    except FileNotFoundError:
        print("O arquivo não foi encontrado.")

if __name__ == "__main__":
    
    file = sys.argv[-1] if len( sys.argv[-1]) > 1 else None
    full_file = True if "-A" in sys.argv else False
    
    nome_do_arquivo_log = file
    monitorar_arquivo_log(nome_do_arquivo_log, full_file)
