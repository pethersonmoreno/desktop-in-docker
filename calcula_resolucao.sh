#!/bin/bash

# Pega as resoluções de todas as telas conectadas
resolucoes=$(xrandr | grep " connected" | sed -E 's/.*[^0-9]([0-9]+x[0-9]+).*/\1/')

total_largura=0
max_altura=0

# Processa cada resolução encontrada
for res in $resolucoes; do
    largura=$(echo $res | cut -d 'x' -f 1)
    altura=$(echo $res | cut -d 'x' -f 2)

    total_largura=$((total_largura + largura))
    
    if [ $altura -gt $max_altura ]; then
        max_altura=$altura
    fi
done

# Verifica se encontrou alguma tela
if [ -z "$resolucoes" ]; then
    echo "Erro: Nenhuma tela conectada encontrada." >&2
    exit 1
else
    # Retorna o resultado em JSON
    echo "{\"total_largura\": \"$total_largura\", \"max_altura\": \"$max_altura\"}"
fi