#!/bin/bash

# Este script tenta obter o endereço IPv4 da interface tun0.
# Se tun0 não estiver ativa ou não tiver um IP, ele não imprimirá nada.

# Verifica se a interface tun0 existe e está UP
if ip link show tun0 > /dev/null 2>&1 && ip link show tun0 | grep -q "state UP"; then
    ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1
fi