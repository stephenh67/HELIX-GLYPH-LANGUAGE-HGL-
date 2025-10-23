#!/usr/bin/env python3
import sys, json, hashlib, argparse
ALLOWED_INTENT={"approve","deny","request"}
ALLOWED_ACT={"access","upsert","execute"}
ALLOWED_KIND={"Human","IAD","CLS"}
ALLOWED_OBJK={"dataset","model","ledger","capability"}
ALLOWED_SCOPE={"read","write","execute"}
def parse_line(line:str)->dict:
  line=" ".join(line.strip().split())
  parts={}; order=["SUBJ:","INTENT:","ACT:","OBJ:","CONSENT:","POLICY:","PROOF:"]
  rest=line
  for i,tag in enumerate(order):
    idx=rest.find(tag)
    if idx==-1: continue
    nxt=len(rest)
    for t2 in order[i+1:]:
      j=rest.find(t2, idx+len(tag)); 
      if j!=-1 and j<nxt: nxt=j
    parts[tag[:-1]]=rest[idx+len(tag):nxt].strip()
  for k in ["SUBJ","INTENT","ACT","OBJ"]:
    if k not in parts: sys.exit("ParseError: missing required field "+k)
  try: kind,subj_id=parts["SUBJ"].split(":",1)
  except ValueError: sys.exit("ParseError: SUBJ must look like Kind:identifier")
  if kind not in ALLOWED_KIND: sys.exit("ParseError: invalid subject kind")
  intent=parts["INTENT"]; act=parts["ACT"]
  if intent not in ALLOWED_INTENT: sys.exit("ParseError: invalid INTENT")
  if act not in ALLOWED_ACT: sys.exit("ParseError: invalid ACT")
  try: obj_kind,obj_id=parts["OBJ"].split("/",1)
  except ValueError: sys.exit("ParseError: OBJ must look like kind/id")
  if obj_kind not in ALLOWED_OBJK: sys.exit("ParseError: invalid OBJ kind")
  out={"sentence_type":"COOP_SENTENCE","v":"0.1",
       "subj":{"kind":kind,"id":subj_id},"intent":intent,"act":act,
       "obj":{"kind":obj_kind,"id":obj_id}}
  if "CONSENT" in parts and parts["CONSENT"]:
    try: scope,until=parts["CONSENT"].split("@",1)
    except ValueError: sys.exit("ParseError: CONSENT must look like scope@until")
    if scope not in ALLOWED_SCOPE: sys.exit("ParseError: invalid CONSENT scope")
    out["consent"]={"scope":scope,"until":until.strip()}
  if "POLICY" in parts and parts["POLICY"]:
    toks=[t for t in parts["POLICY"].replace(","," ").split() if t]
    out["policy"]={"halt_if":toks}
  if "PROOF" in parts and parts["PROOF"]:
    prov={}
    for kv in parts["PROOF"].split(";"):
      if "=" in kv:
        k,v=kv.split("=",1); k=k.strip().lower(); v=v.strip()
        if k in ("sha256","hash"):
          if len(v)!=64 or any(c not in "0123456789abcdefABCDEF" for c in v):
            sys.exit("ParseError: PROOF.sha256 must be 64 hex chars")
          prov["sha256"]=v
        elif k in ("sig","sig_ed25519"):
          prov["sig_ed25519"]=v
    if prov: out["provenance"]=prov
  return out
def canon_json(d:dict)->str: return json.dumps(d, sort_keys=True, separators=(",",":"))
def main():
  ap=argparse.ArgumentParser()
  ap.add_argument("cmd", choices=["compile","canon","hash"])
  ap.add_argument("file")
  a=ap.parse_args()
  if a.cmd=="compile":
    line=open(a.file,"r",encoding="utf-8").read(); print(canon_json(parse_line(line)))
  elif a.cmd=="canon":
    d=json.load(open(a.file,"r",encoding="utf-8")); print(canon_json(d))
  elif a.cmd=="hash":
    d=json.load(open(a.file,"r",encoding="utf-8")); print(hashlib.sha256(canon_json(d).encode()).hexdigest())
  else: sys.exit(1)
if __name__=="__main__": main()
