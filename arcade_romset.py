#!/usr/bin/env python3
"""Confere zips de arcade contra o DAT de um nucleo (spec 010, plano D-03).

Uso: arcade_romset.py --nucleo fbneo|mame2003_plus ZIP... [--pasta-pais DIR]

Para cada zip (o nome do jogo e o nome do arquivo sem .zip):
  - procura o jogo no DAT do nucleo (fonte fixada em .cache/emu/src/<nucleo>);
  - confere os CRC dos arquivos proprios do jogo (sem os herdados do pai, "merge");
  - diz de que pai e BIOS ele precisa (cloneof/romof) e se estao na mesma pasta.
Saida: uma linha por zip, "zip|status|detalhe", status = ok | incompleto | outra_versao | nao_existe.
Codigo de saida: 0 se todos ok.
"""
import argparse
import os
import sys
import xml.etree.ElementTree as ET
import zipfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ports/x.py -> raiz do tutu8bits (spec 053)
SRC = os.path.join(RAIZ, ".cache", "emu", "src")
DATS = {
    "fbneo": os.path.join(SRC, "fbneo", "dats", "FinalBurn Neo (ClrMame Pro XML, Arcade only).dat"),
    "mame2003_plus": os.path.join(SRC, "mame2003_plus", "metadata", "mame2003-plus.xml"),
}


def carregar(dat):
    jogos = {}
    for _, el in ET.iterparse(dat, events=("end",)):
        if el.tag not in ("game", "machine"):
            continue
        roms = []
        for r in el.findall("rom"):
            if r.get("status") == "nodump" or not r.get("crc"):
                continue
            roms.append((r.get("name"), r.get("crc").lower(), r.get("merge")))
        jogos[el.get("name")] = {
            "pai": el.get("cloneof"), "romof": el.get("romof"),
            "bios": el.get("isbios") == "yes", "roms": roms,
            "descricao": (el.findtext("description") or "").strip(),
        }
        el.clear()
    return jogos


def crcs_zip(caminho):
    with zipfile.ZipFile(caminho) as z:
        return {"%08x" % i.CRC for i in z.infolist()}


def conferir(jogos, caminho):
    nome = os.path.splitext(os.path.basename(caminho))[0]
    j = jogos.get(nome)
    if not j:
        return "nao_existe", "jogo nao esta no DAT deste nucleo"
    proprios = [r for r in j["roms"] if not r[2]]
    tem = crcs_zip(caminho)
    faltam = [r[0] for r in proprios if r[1] not in tem]
    deps = [d for d in (j["pai"], j["romof"] if j["romof"] != j["pai"] else None) if d]
    pasta = os.path.dirname(caminho)
    ausentes = [d for d in deps if not os.path.exists(os.path.join(pasta, d + ".zip"))]
    det = j["descricao"]
    if deps:
        det += " | precisa de: " + ", ".join(d + ".zip" for d in deps)
        if ausentes:
            det += " (AUSENTE: " + ", ".join(ausentes) + ")"
    if not faltam and not ausentes:
        return "ok", det
    if faltam and len(faltam) == len(proprios):
        return "outra_versao", det + " | nenhum CRC bate (romset de outra versao)"
    if faltam:
        return "incompleto", det + " | faltam %d de %d: %s" % (len(faltam), len(proprios), ", ".join(faltam[:6]))
    return "incompleto", det


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nucleo", required=True, choices=sorted(DATS))
    ap.add_argument("zips", nargs="+")
    a = ap.parse_args()
    jogos = carregar(DATS[a.nucleo])
    todos_ok = True
    for z in a.zips:
        st, det = conferir(jogos, z)
        todos_ok &= st == "ok"
        print("%s|%s|%s" % (os.path.basename(z), st, det))
    sys.exit(0 if todos_ok else 1)


if __name__ == "__main__":
    main()
