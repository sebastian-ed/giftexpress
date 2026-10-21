#!/bin/sh
cd "$(dirname "$0")" || exit 1
printf 'GiftExpress disponible en http://localhost:8765/\n'
python3 -m http.server 8765 --bind 127.0.0.1
