#!/usr/bin/env bash

zscroll -l 25 \
    --delay 0.3 \
    --update-check true \
    --update-interval 1 \
    "playerctl -p spotify metadata --format '{{title}} - {{artist}}' 2>/dev/null" 2>/dev/null

wait
