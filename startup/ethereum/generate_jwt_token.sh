#!/usr/bin/env bash

mkdir -p jwt
openssl rand -hex 32 | tr -d "\n" > jwt/jwt.hex
