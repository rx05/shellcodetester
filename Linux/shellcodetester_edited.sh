#!/usr/bin/env bash
#
LANG=C
LC_ALL=C
filename="${1%%.*}"
# Error messages array
error_msg[1]='Utilização: shellcodetester [arquivo.asm] --break-point'
error_msg[2]='Erro montando arquivo .asm'
error_msg[3]='Erro na compilação!'

#Error message function
error (){

  echo -e "\n${error_msg[$1]}\n"
  exit $1

}

[[ $# -eq 0 ]] && error 1

gcc_flags=""
c_file="$filename-shellcodetester.c"
o_file="$filename-shellcodetester.o"
bin_file="$filename-shellcodetester"
bp=""

for arg in "$@"; do

	[[ $arg == '--break-point' ]] && echo 'Adicionando breakpoint antes do shellcode' && bp='0xCC'

done


bits64=$(grep -i '\[BITS 64\]' "$1")

if [[ $bits64 ]]; then
    echo "Arquitetura: 64 bits"
else
    echo "Arquitetura: 32 bits"
    gcc_flags=" -m32 "
fi

echo "Montando arquivo \e[32;1m$filename\e[m em $o_file"
rm -rf /tmp/sct.o >/dev/null 2>&1
nasm $1 -o $o_file

[[ $? -ne 0 ]] && error 2

echo "Gerando arquivo $c_file"

cat << EOF > $c_file
#include<stdio.h>
#include<string.h>
#include <sys/mman.h>
unsigned char code[] = {
EOF

echo -n "$bp" >> $c_file

cat $o_file | xxd --include >> $c_file

cat << EOF >> $c_file
};
void main()
{
    char *shell;
    int size = sizeof(code);
    printf("Shellcode Length:  %d\n", size);
    shell = (char*)mmap(NULL, size, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_ANON|MAP_SHARED, -1, 0);
    memcpy(shell,code,size);
    int (*ret)() = (int(*)())shell;
    ret();
}
EOF

l=$(cat $o_file | wc -c)
t_payload=$(cat $o_file | xxd -p | tr -d '\n')
l2=${#t_payload}

payload=""
i=0
while [[ $i -le $l2 ]]; do

    hex=${t_payload:$i:2}
    [[ "$hex" == "00" ]] && payload="$payload\033[0;31m00\033[0m" || payload="$payload$hex"

    i=$(( $i + 2 ))

done

echo "Compilando arquivo $c_file para $bin_file"
gcc $c_file -o $bin_file $gcc_flags -fno-stack-protector -z execstack
if [[ $? -eq 0 ]]; then

echo -e \
"Montagem e compilação realizada com sucesso.\n
Tamanho do Payload: $l bytes
Tamanho do Payload: Tamanho final em hexa: $l2 bytes
$payload\n
Execute o comando ./$bin_file\n"

else

    error 3
fi
