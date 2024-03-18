import re
import sys

regex = re.compile(r"""
(?:IN=(\S*))                                  
|                                              
(?:OUT=(\S*))                              
|                                             
(?:SRC=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}))  
|                                            
(?:DST=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}))  
|                                            
(?:PROTO=(\S*))
|
(?:SPT=(\d*))
|
(?:DPT=(>\d*))
""", re.VERBOSE)


def monitorar_arquivo_log(nome_arquivo, full_file):
    try:
        with open(nome_arquivo, 'r') as arquivo:
            if full_file is False:
                arquivo.seek(0, 2)
            while True:
                linha = arquivo.readline()
                if not linha or not "iptables" in linha:
                    continue
                
                DIA = linha[4:6]
                MES = linha[0:3]
                HORA = linha[7:15]

                matches = re.findall(regex, linha)
                result = {k: v for match in matches for k, v in zip(('IN', 'OUT', 'SRC', 'DST', 'PROTO', 'DPT', 'SPT'), match) if v}

                sentido = "\033[1;36mINP ->\033[m" if result.get('IN') else "\033[1;31mOUT ->\033[m"
                iface = result.get('IN') or result.get('OUT')
                
                SPT = " (\033[1;36m{}\033[0m)".format(result.get('SPT')) if result.get('SPT') else ""
                DPT = " (\033[1;36m{}\033[0m)".format(result.get('DPT')) if result.get('DPT') else ""
                PROTO = " \033[1;33m{}\033[1;31m ".format(result.get('PROTO')) if result.get('PROTO') else ""
                print(
"""\033[1;31m[DROPED]   \033[1;35m{} {} \033[m[\033[1;35m{}\033[0m] - - - - \033[1;32m{}\033[m{} - \
\033[1;31m=={}=>\033[m - \033[1;32m{}\033[m{} - - \
{} \033[1;33m{}\033[0m""".format(DIA,
                                 MES,
                                 HORA,
                                 result.get('SRC'),
                                 SPT,
                                 PROTO,
                                 result.get('DST'),
                                 DPT,
                                 sentido,
                                 iface), end="\n\n")
          
    except FileNotFoundError:
        print("O arquivo não foi encontrado.")

if __name__ == "__main__":
    
    file = sys.argv[-1] if len( sys.argv[-1]) > 1 else None
    full_file = True if "-A" in sys.argv else False
    
    nome_do_arquivo_log = file
    monitorar_arquivo_log(nome_do_arquivo_log, full_file)
