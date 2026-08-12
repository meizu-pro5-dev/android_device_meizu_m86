#!/usr/bin/env python3
"""Build the m86 AP-navigation DTB from the hash-locked Flyme DTB.

The release DTB keeps every stock byte except the zero-length ``secure-mode``
property on SPI4.  The property token is replaced by FDT_NOP tokens, so node
offsets, phandles, GPIO data and the string table remain unchanged.  The raw
FPC driver deliberately accepts the stock child compatible and GPIO names.
"""

import argparse
import hashlib
import pathlib
import struct
import tempfile


FDT_MAGIC = 0xD00DFEED
FDT_BEGIN_NODE = 0x1
FDT_END_NODE = 0x2
FDT_PROP = 0x3
FDT_NOP = 0x4
FDT_END = 0x9
FDT_HEADER = struct.Struct(">10I")
STOCK_SHA256 = "b45054fa87a5ffe114843953172d48d36408e1f93db35a6cbdfb0a8fc58a2165"
SPI_PATH = "/spi@14d70000"
FPC_PATH = SPI_PATH + "/securefpc_spidev@0"


def _align4(value):
    return (value + 3) & ~3


def _cstring(blob, offset, limit):
    end = blob.find(b"\0", offset, limit)
    if end < 0:
        raise RuntimeError("unterminated FDT string")
    return blob[offset:end].decode("ascii")


def _parse_header(blob):
    if len(blob) < FDT_HEADER.size:
        raise RuntimeError("stock DTB is truncated")
    fields = FDT_HEADER.unpack_from(blob)
    if fields[0] != FDT_MAGIC:
        raise RuntimeError("stock input is not an FDT")
    totalsize = fields[1]
    if totalsize > len(blob) or totalsize < FDT_HEADER.size:
        raise RuntimeError("invalid FDT total size")
    return {
        "totalsize": totalsize,
        "struct_offset": fields[2],
        "strings_offset": fields[3],
        "strings_size": fields[8],
        "struct_size": fields[9],
    }


def _read_tree(blob, patch_secure_mode):
    header = _parse_header(blob)
    struct_start = header["struct_offset"]
    struct_end = struct_start + header["struct_size"]
    strings_start = header["strings_offset"]
    strings_end = strings_start + header["strings_size"]
    if struct_end > header["totalsize"] or strings_end > header["totalsize"]:
        raise RuntimeError("FDT blocks exceed total size")

    output = bytearray(blob[:header["totalsize"]])
    offset = struct_start
    nodes = []
    properties = {}
    patched_offsets = []
    saw_end = False

    while offset + 4 <= struct_end:
        token_offset = offset
        token = struct.unpack_from(">I", blob, offset)[0]
        offset += 4
        if token == FDT_BEGIN_NODE:
            name = _cstring(blob, offset, struct_end)
            offset = _align4(offset + len(name.encode("ascii")) + 1)
            nodes.append(name)
        elif token == FDT_END_NODE:
            if not nodes:
                raise RuntimeError("unbalanced FDT_END_NODE")
            nodes.pop()
        elif token == FDT_PROP:
            if offset + 8 > struct_end or not nodes:
                raise RuntimeError("invalid FDT property header")
            length, name_offset = struct.unpack_from(">II", blob, offset)
            offset += 8
            if name_offset >= header["strings_size"]:
                raise RuntimeError("invalid FDT property name offset")
            name = _cstring(blob, strings_start + name_offset, strings_end)
            if offset + length > struct_end:
                raise RuntimeError("FDT property exceeds structure block")
            value = bytes(blob[offset:offset + length])
            path = "/" + "/".join(part for part in nodes if part)
            properties.setdefault(path, {})[name] = value
            if patch_secure_mode and path == SPI_PATH and name == "secure-mode":
                if length != 0:
                    raise RuntimeError("SPI4 secure-mode property is not empty")
                for nop_offset in range(token_offset, token_offset + 12, 4):
                    struct.pack_into(">I", output, nop_offset, FDT_NOP)
                patched_offsets.append(token_offset)
            offset = _align4(offset + length)
        elif token == FDT_NOP:
            continue
        elif token == FDT_END:
            if nodes:
                raise RuntimeError("FDT ended with open nodes")
            saw_end = True
            break
        else:
            raise RuntimeError("unknown FDT token 0x{:x}".format(token))

    if not saw_end:
        raise RuntimeError("FDT structure has no end token")
    return bytes(output), properties, patched_offsets


def _require_stock_contract(properties):
    spi = properties.get(SPI_PATH, {})
    fpc = properties.get(FPC_PATH, {})
    if "secure-mode" not in spi:
        raise RuntimeError("stock SPI4 secure-mode property is missing")
    if fpc.get("compatible") != b"fpc,fpc_irq\0":
        raise RuntimeError("stock FPC compatible changed")
    for gpio_name in ("gx,gpio_irq", "gx,gpio_reset"):
        if gpio_name not in fpc:
            raise RuntimeError("stock FPC property is missing: {}".format(gpio_name))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stock", required=True)
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output")
    destination.add_argument("--verify")
    args = parser.parse_args()

    stock_path = pathlib.Path(args.stock)
    stock = stock_path.read_bytes()
    header = _parse_header(stock)
    stock = stock[:header["totalsize"]]
    stock_hash = hashlib.sha256(stock).hexdigest()
    if stock_hash != STOCK_SHA256:
        raise RuntimeError("stock Flyme DTB hash does not match the device baseline")

    _, stock_properties, _ = _read_tree(stock, False)
    _require_stock_contract(stock_properties)
    output, _, patched_offsets = _read_tree(stock, True)
    if len(patched_offsets) != 1:
        raise RuntimeError("expected exactly one SPI4 secure-mode property")

    _, output_properties, _ = _read_tree(output, False)
    if "secure-mode" in output_properties.get(SPI_PATH, {}):
        raise RuntimeError("AP-navigation DTB retained SPI4 secure-mode")
    if output_properties.get(FPC_PATH) != stock_properties.get(FPC_PATH):
        raise RuntimeError("AP-navigation DTB changed the stock FPC child")
    changed_bytes = sum(left != right for left, right in zip(stock, output))
    if len(output) != len(stock) or changed_bytes != 4:
        raise RuntimeError("DTB mutation exceeded the three FDT token words")

    if args.verify:
        verified = pathlib.Path(args.verify).read_bytes()
        if verified != output:
            raise RuntimeError("verified DTB differs from the mBack derivation")
    else:
        output_path = pathlib.Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
                prefix=output_path.name + ".", dir=output_path.parent,
                delete=False) as temporary:
            temporary.write(output)
            temporary_path = pathlib.Path(temporary.name)
        temporary_path.replace(output_path)

    print("stock_dtb_sha256={}".format(stock_hash))
    print("mback_dtb_sha256={}".format(hashlib.sha256(output).hexdigest()))
    print("mback_dtb_patch={}:secure-mode->FDT_NOP".format(SPI_PATH))
    print("mback_dtb_changed_bytes={}".format(changed_bytes))


if __name__ == "__main__":
    main()
