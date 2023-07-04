#!/usr/bin/env python3

from jinja2 import Template
import argparse


def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Generate blockchain schema",
    )
    parser.add_argument("-c", "--chain", default="ethereum", help="Blockchain name")
    parser.add_argument(
        "--template-file", default="schema/evm.sql", help="Template file"
    )
    parser.add_argument(
        "--timescale-db",
        action="store_true",
        help="Database support TimescaleDB extension",
    )
    parser.add_argument(
        "--create-address-index",
        action="store_true",
        help="Create {from,to,token}_address related index",
    )
    parser.add_argument(
        "--create-blknum-index",
        action="store_true",
        help="Create block number related index",
    )
    args = parser.parse_args()

    with open(args.template_file) as fr:
        temp = Template(fr.read())
    result = temp.render(
        chain=args.chain,
        is_timescale_db=args.timescale_db,
        create_address_index=args.create_address_index,
        create_blknum_index=args.create_blknum_index,
    )
    print(result)


if __name__ == "__main__":
    main()
