-- Hex string into Numeric
CREATE OR REPLACE FUNCTION hex_to_bn(s text) RETURNS NUMERIC
AS $$
    return int(s, 16)
$$ LANGUAGE plpython3u;


-- Convert Hex string into Tron address
-- '000000000000000000000000a2c2426d23bb43809e6eba1311afddde8d45f5d8' -> 'TQooBX9o8iSSprLWW96YShBogx7Uwisuim'
CREATE OR REPLACE FUNCTION hex_to_tron(s text) RETURNS TEXT
AS $$
    import base58
    if len(s) < 40:
        raise ValueError('address must be at least 40 characters')

    addr = '41' + s[-40:]
    return base58.b58encode_check(bytes.fromhex(addr)).decode()
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION safe_eth_decode_input(abi_json json, data text) RETURNS JSON
AS $$
    import json
    from eth_abi.abi import decode_single

    def collapse_if_tuple(abi) -> str:
        """
        Converts a tuple from a dict to a parenthesized list of its types.

        >>> from eth_utils.abi import collapse_if_tuple
        >>> collapse_if_tuple(
        ...     {
        ...         'components': [
        ...             {'name': 'anAddress', 'type': 'address'},
        ...             {'name': 'anInt', 'type': 'uint256'},
        ...             {'name': 'someBytes', 'type': 'bytes'},
        ...         ],
        ...         'type': 'tuple',
        ...     }
        ... )
        '(address,uint256,bytes)'
        """
        typ = abi["type"]
        if not isinstance(typ, str):
            raise TypeError(
                "The 'type' must be a string, but got %r of type %s" % (typ, type(typ))
            )
        elif not typ.startswith("tuple"):
            return typ

        delimited = ",".join(collapse_if_tuple(c) for c in abi["components"])
        # Whatever comes after "tuple" is the array dims.  The ABI spec states that
        # this will have the form "", "[]", or "[k]".
        array_dim = typ[5:]
        collapsed = "({}){}".format(delimited, array_dim)

        return collapsed

    def zip_if_tuple(abi, value):
        typ = abi["type"]
        name = abi["name"]
        if typ.startswith("byte"):
            # list
            if typ.endswith("]"):
                values = [v.hex() for v in value]
                result = []
                for vs in values:
                    vss = [vs[n : n + 64] for n in range(0, len(vs), 64)]
                    # the last element's suffix maybe not complete
                    # see https://etherscan.io/tx/0xc4bdb99faa13446888db5a66c8e9f42606f0ccd7ec7a2d733012a867a34be0ec # noqa
                    if len(vss[-1]) < 64:
                        # suffix with zero
                        vss[-1] = vss[-1] + "0" * (64 - len(vss[-1]))
                    result.extend(vss)
                return {name: result}
            else:
                return {name: value.hex()}
        if not typ.startswith("tuple"):
            return {name: value}

        is_array = len(typ) > len("tuple")

        subabi = abi["components"]
        if not is_array:
            subvalue = {}
            for idx, sa in enumerate(subabi):
                subvalue.update(zip_if_tuple(sa, value[idx]))
            return {name: subvalue}
        else:
            subvalues = []
            for sv in value:
                subvalue = {}
                for idx, sa in enumerate(subabi):
                    subvalue.update(zip_if_tuple(sa, sv[idx]))
                subvalues.append(subvalue)
            return {name: subvalues}

    func_abi = json.loads(abi_json)
    if "name" not in func_abi:
        return "{}"

    try:
        inputs = func_abi.get("inputs", [])
        func_sign = "({})".format(",".join(collapse_if_tuple(abi) for abi in inputs))
        func_text = "{}{}".format(func_abi["name"], func_sign)

        decoded = decode_single(func_sign, bytes(bytearray.fromhex(data[10:])))
        parameter = {}
        for idx, value in enumerate(decoded):
            parameter.update(zip_if_tuple(inputs[idx], value))

        return json.dumps({"method": func_text, "parameter": parameter})
    except Exception:
        return "{}"
$$ LANGUAGE plpython3u;


CREATE OR REPLACE FUNCTION eth_decode_input2(abi_json json, data text) RETURNS JSON
AS $$
    import json
    from eth_abi.abi import decode_single

    def collapse_if_tuple(abi) -> str:
        """
        Converts a tuple from a dict to a parenthesized list of its types.

        >>> from eth_utils.abi import collapse_if_tuple
        >>> collapse_if_tuple(
        ...     {
        ...         'components': [
        ...             {'name': 'anAddress', 'type': 'address'},
        ...             {'name': 'anInt', 'type': 'uint256'},
        ...             {'name': 'someBytes', 'type': 'bytes'},
        ...         ],
        ...         'type': 'tuple',
        ...     }
        ... )
        '(address,uint256,bytes)'
        """
        typ = abi["type"]
        if not isinstance(typ, str):
            raise TypeError(
                "The 'type' must be a string, but got %r of type %s" % (typ, type(typ))
            )
        elif not typ.startswith("tuple"):
            return typ

        delimited = ",".join(collapse_if_tuple(c) for c in abi["components"])
        # Whatever comes after "tuple" is the array dims.  The ABI spec states that
        # this will have the form "", "[]", or "[k]".
        array_dim = typ[5:]
        collapsed = "({}){}".format(delimited, array_dim)

        return collapsed

    def zip_if_tuple(abi, value):
        typ = abi["type"]
        name = abi["name"]
        if typ.startswith("byte"):
            # list
            if typ.endswith("]"):
                values = [v.hex() for v in value]
                result = []
                for vs in values:
                    vss = [vs[n : n + 64] for n in range(0, len(vs), 64)]
                    # the last element's suffix maybe not complete
                    # see https://etherscan.io/tx/0xc4bdb99faa13446888db5a66c8e9f42606f0ccd7ec7a2d733012a867a34be0ec # noqa
                    if len(vss[-1]) < 64:
                        # suffix with zero
                        vss[-1] = vss[-1] + "0" * (64 - len(vss[-1]))
                    result.extend(vss)
                return {name: result}
            else:
                return {name: value.hex()}
        if not typ.startswith("tuple"):
            return {name: value}

        is_array = len(typ) > len("tuple")

        subabi = abi["components"]
        if not is_array:
            subvalue = {}
            for idx, sa in enumerate(subabi):
                subvalue.update(zip_if_tuple(sa, value[idx]))
            return {name: subvalue}
        else:
            subvalues = []
            for sv in value:
                subvalue = {}
                for idx, sa in enumerate(subabi):
                    subvalue.update(zip_if_tuple(sa, sv[idx]))
                subvalues.append(subvalue)
            return {name: subvalues}

    func_abi = json.loads(abi_json)
    if "name" not in func_abi:
        return "{}"

    inputs = func_abi.get("inputs", [])
    func_sign = "({})".format(",".join(collapse_if_tuple(abi) for abi in inputs))
    func_text = "{}{}".format(func_abi["name"], func_sign)

    decoded = decode_single(func_sign, bytes(bytearray.fromhex(data[10:])))
    parameter = {}
    for idx, value in enumerate(decoded):
        parameter.update(zip_if_tuple(inputs[idx], value))

    return json.dumps({"method": func_text, "parameter": parameter})
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION eth_decode_input(addr text, data text) RETURNS JSON
AS $$
    import json
    from eth_abi.abi import decode_abi

    func_sign = data[:10]
    rv = plpy.execute(
        "SELECT abi, prototype FROM ethereum.func_signatures WHERE address = '%s' AND byte_sign = '%s'"
        % (addr, func_sign),
        1,
    )
    if len(rv) < 1:
        return "{}"

    func_abi = json.loads(rv[0]["abi"])
    if "name" not in func_abi:
        return "{}"

    func_text = rv[0]["prototype"]

    idx_dict = {}
    types, names = [], []
    bytes_names = []
    for idx, abi in enumerate(func_abi["inputs"]):
        types.append(abi["type"])
        name = abi.get("name", "")
        idx_name = "__idx_%d" %(idx)
        if name == "":
            name = idx_name
        idx_dict[name] = idx_name
        names.append(name)

        if abi["type"].startswith("byte"):
            bytes_names.append(name)
            bytes_names.append(idx_name)

    parameter = dict(zip(names, decode_abi(types, bytes(bytearray.fromhex(data[10:])))))
    for name, idx_name in idx_dict.items():
        parameter[idx_name] = parameter[name]

    for key in bytes_names:
        val = parameter[key]
        if isinstance(val, tuple):
            parameter[key] = tuple([e.hex() for e in val])
        elif isinstance(val, bytes):
            parameter[key] = val.hex()

    return json.dumps({"method": func_text, "parameter": parameter})
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION eth_decode_input(abi_json json, data text) RETURNS JSON
AS $$
    import json
    from eth_abi.abi import decode_abi

    func_abi = json.loads(abi_json)
    if "name" not in func_abi:
        return "{}"

    func_text = "{}({})".format(
        func_abi["name"],
        ", ".join(
            [
                e["type"] + " " + e.get("name", "")
                for e in func_abi.get("inputs", [])
            ]
        ),
    )

    idx_dict = {}
    types, names = [], []
    bytes_names = []
    for idx, abi in enumerate(func_abi["inputs"]):
        types.append(abi["type"])
        name = abi.get("name", "")
        idx_name = "__idx_%d" %(idx)
        if name == "":
            name = idx_name
        idx_dict[name] = idx_name
        names.append(name)

        if abi["type"].startswith("byte"):
            bytes_names.append(name)
            bytes_names.append(idx_name)

    parameter = dict(zip(names, decode_abi(types, bytes(bytearray.fromhex(data[10:])))))
    for name, idx_name in idx_dict.items():
        parameter[idx_name] = parameter[name]

    for key in bytes_names:
        val = parameter[key]
        if isinstance(val, tuple):
            parameter[key] = tuple([e.hex() for e in val])
        elif isinstance(val, bytes):
            parameter[key] = val.hex()

    return json.dumps({"method": func_text, "parameter": parameter})
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION eth_decode_log(abi_json json, topics text, data text) RETURNS JSON
AS $$
    import json
    from eth_abi.abi import decode_abi, decode_single
    from itertools import chain

    # Compatible with [] surrounded string or normal string
    _topics = topics.lstrip("[").rstrip("]").split(",")
    # topics_0 is the Event signature
    _topics = _topics[1:]

    event_abi = json.loads(abi_json)
    if "name" not in event_abi or event_abi.get("type") != "event":
        return "{}"

    # rewrite the indexed columns first
    if "inputs" in event_abi:
        indexed, normal = [], []
        for input in event_abi.get("inputs", []):
            if input.get("indexed") is True:
                indexed.append(input)
            else:
                normal.append(input)
        event_abi["inputs"] = indexed + normal

    func_text = "{}({})".format(
        event_abi["name"],
        ", ".join(
            [e["type"] + " " + e.get("name", "") for e in event_abi.get("inputs", [])]
        ),
    )

    idx_dict = {}
    types, names = [], []
    indexed_names, indexed_types = [], []
    bytes_names = []
    for idx, abi in enumerate(event_abi["inputs"]):
        name = abi.get("name", "")
        idx_name = "__idx_%d" % (idx)

        if name == "":
            name = idx_name
        idx_dict[name] = idx_name

        if idx < len(_topics):
            indexed_types.append(abi["type"])
            indexed_names.append(name)
        else:
            types.append(abi["type"])
            names.append(name)

        if abi["type"].startswith("byte"):
            bytes_names.append(name)
            bytes_names.append(idx_name)

    values = decode_abi(types, bytes(bytearray.fromhex(data[2:])))

    indexed_values = [
        decode_single(t, bytes(bytearray.fromhex(v[2:])))
        for t, v in zip(indexed_types, _topics)
    ]

    parameter = dict(chain(zip(indexed_names, indexed_values), zip(names, values)))
    for name, idx_name in idx_dict.items():
        parameter[idx_name] = parameter[name]

    for key in bytes_names:
        val = parameter[key]
        if isinstance(val, tuple):
            parameter[key] = tuple([e.hex() for e in val])
        elif isinstance(val, bytes):
            parameter[key] = val.hex()

    return json.dumps({"method": func_text, "parameter": parameter})
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION eth_decode_log(addr text, topics text, data text) RETURNS JSON
AS $$
    import json
    from eth_abi import decode_abi, decode_single
    from itertools import chain

    # Compatible with [] surrounded string or normal string
    _topics = topics.lstrip("[").rstrip("]").split(",")

    byte_sign = _topics[0]
    rv = plpy.execute(
        "SELECT abi, prototype FROM ethereum.\"func_signatures\" WHERE address = '%s' AND byte_sign = '%s' LIMIT 1"
        % (addr, byte_sign),
        1,
    )
    if len(rv) < 1:
        return "{}"

    func_abi = json.loads(rv[0]["abi"])
    if "name" not in func_abi:
        return "{}"

    # rewrite the indexed columns first
    if "inputs" in event_abi:
        indexed, normal = [], []
        for input in event_abi.get("inputs", []):
            if input.get("indexed") is True:
                indexed.append(input)
            else:
                normal.append(input)
        event_abi["inputs"] = indexed + normal

    func_text = rv[0]["prototype"]

    idx_dict = {}
    types, names = [], []
    indexed_names, indexed_types = [], []
    bytes_names = []
    for idx, abi in enumerate(func_abi["inputs"]):
        name = abi.get("name", "")
        idx_name = "__idx_%d" % (idx)

        if name == "":
            name = idx_name
        idx_dict[name] = idx_name

        if abi["indexed"]:
            indexed_types.append(abi["type"])
            indexed_names.append(name)
        else:
            types.append(abi["type"])
            names.append(name)

        if abi["type"].startswith("byte"):
            bytes_names.append(name)
            bytes_names.append(idx_name)

    values = decode_abi(types, bytes(bytearray.fromhex(data[2:])))

    indexed_values = [
        decode_single(t, bytes(bytearray.fromhex(v[2:])))
        for t, v in zip(indexed_types, _topics[1:])
    ]

    parameter = dict(chain(zip(indexed_names, indexed_values), zip(names, values)))
    for name, idx_name in idx_dict.items():
        parameter[idx_name] = parameter[name]

    for key in bytes_names:
        val = parameter[key]
        if isinstance(val, tuple):
            parameter[key] = tuple([e.hex() for e in val])
        elif isinstance(val, bytes):
            parameter[key] = val.hex()

    return json.dumps({"method": func_text, "parameter": parameter})
$$ LANGUAGE plpython3u;
