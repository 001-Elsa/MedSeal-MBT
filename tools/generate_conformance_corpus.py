#!/usr/bin/env python3
"""Original synthetic corpus and independent expectations, never observed output.

The only shared input is checked official dictionary facts. Policy expectations
are explicitly authored in conformance/expectations.json, outside production.
"""
from pathlib import Path
import argparse
import copy
import datetime
import hashlib
import io
import json
import re
import struct
import warnings
import pydicom
from pydicom.dataset import Dataset, FileDataset, FileMetaDataset
from pydicom.sequence import Sequence
from pydicom.multival import MultiValue
from pydicom.uid import ExplicitVRLittleEndian, SecondaryCaptureImageStorage
from moon_tokens import semantic_tokens

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / 'conformance'
EXPECT = json.loads((ROOT / 'expectations.json').read_text(encoding='utf-8'))
FACTS = json.loads((REPO / 'resources/rules/standard-facts-2025e.json').read_text(encoding='utf-8'))


def canonical(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), sort_keys=True, allow_nan=False)


def base():
    meta = FileMetaDataset()
    meta.TransferSyntaxUID = ExplicitVRLittleEndian
    meta.MediaStorageSOPClassUID = SecondaryCaptureImageStorage
    meta.MediaStorageSOPInstanceUID = '1.2.3.30'
    meta.ImplementationClassUID = '1.2.3.99'
    ds = FileDataset(None, {}, file_meta=meta, preamble=bytes(128))
    ds.SpecificCharacterSet = 'ISO_IR 192'
    values = {
        'SOPClassUID': SecondaryCaptureImageStorage, 'SOPInstanceUID': '1.2.3.30',
        'PatientName': 'SYNTHETIC^SOURCE', 'PatientID': 'SYNTHETIC-ID',
        'PatientBirthDate': '19700101', 'PatientSex': 'O',
        'StudyInstanceUID': '1.2.3.10', 'SeriesInstanceUID': '1.2.3.20',
        'StudyDate': '20240229', 'StudyTime': '123456', 'ReferringPhysicianName': 'SYNTHETIC^REFERRER',
        'StudyID': 'SYNTHETIC', 'AccessionNumber': 'SYNTHETIC', 'SeriesNumber': 1, 'InstanceNumber': 1,
        'PatientOrientation': '', 'Laterality': '', 'ConversionType': 'WSD', 'Manufacturer': 'SYNTHETIC',
        'StudyDescription': 'SYNTHETIC-STUDY', 'Modality': 'OT', 'LossyImageCompression': '00',
        'SamplesPerPixel': 1, 'PhotometricInterpretation': 'MONOCHROME2',
        'Rows': 2, 'Columns': 2, 'BitsAllocated': 8, 'BitsStored': 8,
        'HighBit': 7, 'PixelRepresentation': 0, 'PixelData': b'\x00\x40\x80\xff',
    }
    for key, value in values.items():
        setattr(ds, key, value)
    ds[0x7fe00010].VR = 'OB'
    return ds


def encode(ds):
    if getattr(ds, 'SOPClassUID', None):
        ds.file_meta.MediaStorageSOPClassUID = ds.SOPClassUID
    if getattr(ds, 'SOPInstanceUID', None):
        ds.file_meta.MediaStorageSOPInstanceUID = ds.SOPInstanceUID
    stream = io.BytesIO()
    pydicom.dcmwrite(stream, ds, enforce_file_format=True)
    return stream.getvalue()


def normalized(ds):
    result = []
    for e in sorted(ds, key=lambda e: e.tag):
        value = e.value
        if e.VR == 'SQ':
            value = [normalized(item) for item in value]
        elif value is None or value == '':
            value = None
        elif isinstance(value, bytes):
            value = ['raw', len(value), hashlib.sha256(value).hexdigest()]
        elif e.VR == 'AT':
            values = list(value) if isinstance(value, (MultiValue, list, tuple)) else [value]
            raw = b''.join(struct.pack('<HH', v.group, v.element) for v in values)
            value = ['raw', len(raw), hashlib.sha256(raw).hexdigest()]
        elif e.VR in {'US', 'SS', 'UL', 'SL'}:
            value = list(value) if isinstance(value, (MultiValue, list, tuple)) else [value]
        else:
            values = list(value) if isinstance(value, (MultiValue, list, tuple)) else [value]
            value = '\\'.join(getattr(v, 'original_string', str(v)) if e.VR in {'DS','IS'} else str(v) for v in values)
        result.append([f'{int(e.tag):08X}', e.VR, value])
    return result


def after_model(ds, config=None):
    """Independent expected actions, dates and fixed documented UID allocation."""
    uid_values = set()
    def collect(item):
        for e in item:
            tag = f'{int(e.tag):08X}'
            if e.tag.is_private or EXPECT['actions'].get(tag) == 'remove':
                continue
            if EXPECT['actions'].get(tag) == 'remap':
                uid_values.add(str(e.value))
            if e.VR == 'SQ':
                for nested in e.value:
                    collect(nested)
    collect(ds)
    mappings = {value: '2.25.' + str(12345 * 1000001 + i + 1) for i, value in enumerate(sorted(uid_values))}
    def apply(item):
        result = []
        for tag, vr, value in normalized(item):
            number = int(tag, 16)
            group, element = number >> 16, number & 65535
            if group % 2 or element == 0 or group in {0x0400, 0xfffa, 0xfffc} or 0x6000 <= group <= 0x60ff:
                continue
            action = EXPECT['actions'][tag]
            retain_dt = config and config.get('temporal_policy') == 'retain-dt-precision-v1'
            if retain_dt and tag == '0008002A':
                action = 'shift'
            if retain_dt and tag == '00080201':
                # An explicit timezone is retained only when the DT has no
                # offset and supplies a complete calendar date.
                dt = str(ds.get(0x0008002A).value) if 0x0008002A in ds else ''
                action = 'keep' if len(dt) >= 8 and not (dt[-5:-4] in {'+', '-'}) else 'remove'
            if action == 'remove':
                continue
            if action == 'replace':
                value = 'P1^' if tag == '00100010' else 'P1'
            elif action == 'empty':
                value = None
            elif action == 'remap' and value is not None:
                value = '\\'.join(mappings[v] for v in value.split('\\'))
            elif action == 'shift' and value is not None:
                if tag == '0008002A':
                    shifted = []
                    for v in value.split('\\'):
                        body, suffix = v, ''
                        if len(v) >= 5 and v[-5] in '+-':
                            body, suffix = v[:-5], v[-5:]
                        if len(body) < 8:
                            shifted.append(None)
                        else:
                            shifted.append((datetime.datetime.strptime(body[:8], '%Y%m%d') + datetime.timedelta(days=(config or {}).get('date_shift_days', 14))).strftime('%Y%m%d') + body[8:] + suffix)
                    value = None if len(shifted) == 1 and shifted[0] is None else '\\'.join('' if item is None else item for item in shifted)
                else:
                    value = '\\'.join((datetime.datetime.strptime(v, '%Y%m%d') + datetime.timedelta(days=14)).strftime('%Y%m%d') for v in value.split('\\'))
            elif action == 'recurse':
                value = [apply(nested) for nested in item[int(tag, 16)].value]
            if config and tag == '00081030':
                eligible = [r for r in config.get('path_rules', []) if r['path'] == 'dataset/00081030' and
                            (r.get('when_sop') is None or r['when_sop'] == str(ds.SOPClassUID)) and
                            (r.get('when_present') is None or int(r['when_present'], 16) in item)]
                if eligible:
                    chosen = max(eligible, key=lambda r: r['priority'])
                    if chosen['action'] == 'remove':
                        continue
                    value = chosen['value'] if chosen['action'] == 'replace' else None
            result.append([tag, vr, value])
        return sorted(result)
    result = apply(ds)
    result.append(['00120063', 'LO', 'MedSeal strict-v1; metadata subset; pixels unchecked'])
    return sorted(result)


def sample(ds, tag, vr, vm):
    number = int(tag, 16)
    if number in ds:
        return
    count = int(vm.split('-')[0])
    if vr == 'SQ':
        item = Dataset()
        if tag == '00081140':
            item.ReferencedSOPClassUID = SecondaryCaptureImageStorage
            item.ReferencedSOPInstanceUID = ds.SOPInstanceUID
        else:
            item.PatientName = 'SYNTHETIC^NESTED'
        value = Sequence([item])
    elif vr in {'OB', 'OW', 'OF', 'OD', 'OL', 'OV', 'UN'}:
        value = bytes(8)
    elif vr in {'US', 'SS', 'UL', 'SL'}:
        value = list(range(1, count + 1)) if count > 1 else 1
    elif vr == 'AT':
        value = 0x00180050
    else:
        value = {'UI': '1.2.3.40', 'DA': '20240229', 'DT': '20240229123456.123456+0800',
                 'TM': '123456.123456', 'DS': '1', 'IS': '1', 'AS': '007Y', 'CS': 'SYNTHETIC',
                 'SH': 'SYNTHETIC', 'LO': 'SYNTHETIC', 'PN': 'SYNTHETIC^SOURCE'}.get(vr, 'SYNTHETIC')
        if tag == '00080201': value = '+0800'
        if count > 1:
            value = [value] * count
    ds.add_new(number, vr, value)


def element_span(raw, tag):
    packed = struct.pack('<HH', int(tag[:4], 16), int(tag[4:], 16))
    offset = raw.find(packed, 132)
    assert offset >= 0, tag
    vr = raw[offset + 4:offset + 6].decode('ascii')
    long = vr in {'OB','OD','OF','OL','OV','OW','SQ','UC','UN','UR','UT','SV','UV'}
    length = struct.unpack_from('<I' if long else '<H', raw, offset + (8 if long else 6))[0]
    start = offset + (12 if long else 8)
    return offset, start, length, long


def products():
    fixtures, entries = {}, []
    def add(identifier, category, ds=None, raw=None, mode='pipeline', tag='', blocked=None, rule=None, stage=None, config=None, rules=None, recipe=None, iod=False):
        data = encode(ds) if raw is None else raw
        filename = identifier + '.dcm'
        expected = {'status': 'blocked', 'code': blocked} if blocked else {'status': 'passed'}
        if rule:
            expected.update(rule_id=rule, stage=stage)
        if not blocked and mode != 'policy':
            model = normalized(pydicom.dcmread(io.BytesIO(data)))
            expected.update(before=model, roundtrip=model)
            if mode == 'pipeline':
                expected.update(after=after_model(pydicom.dcmread(io.BytesIO(data)), config), release_authorized=False)
        config_text = canonical(config) if config else ''
        fixtures[ROOT / 'fixtures' / filename] = data
        entry = {'id': identifier, 'category': category, 'file': 'fixtures/' + filename,
                 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data), 'required': True,
                 'source': 'original synthetic; no patient data', 'license': 'Apache-2.0',
                 'purpose': mode, 'tag': tag, 'configuration': config_text, 'expected': expected,
                 'rules': rules or ([rule] if rule else []), 'recipe': recipe, 'iod_validator': iod}
        entries.append(entry)
    for tag, action in EXPECT['actions'].items():
        fact = FACTS['reviewed_dictionary_facts'][tag]
        vr, vm = fact['vr'].split(' or ')[0], fact['vm']
        ds = base()
        sample(ds, tag, vr, vm)
        add('field-' + tag + '-valid', 'valid', ds, mode='field', tag=tag, rules=['attr-' + tag])
        data = bytearray(encode(ds))
        offset, _, _, long = element_span(data, tag)
        data[offset + 4:offset + 6] = b'UN' if long else (b'SH' if vr == 'LO' else b'LO')
        add('field-' + tag + '-vr-invalid', 'malformed', raw=bytes(data), mode='field', tag=tag,
            blocked='MEDSEAL-E530', rule='attr-' + tag, stage='vr')
        # Full converter action evidence is separate from the dictionary units.
        if tag != '00120063':
            add('action-' + tag, 'privacy-risk' if action in {'remove','empty','replace','remap','shift'} else 'valid', ds,
                rules=['attr-' + tag], iod=tag in {'00100010','00100020','00080018','00080020','00080070'})
    ds = base()
    add('sc-baseline', 'valid', ds, iod=True)
    for bits in [8,16]:
        for rows, cols in [(1,1),(3,5),(8,8)]:
            changed = base()
            changed.Rows, changed.Columns = rows, cols
            changed.BitsAllocated = changed.BitsStored = bits
            changed.HighBit = bits-1
            changed.PixelData = bytes((i % 256 for i in range(rows*cols*bits//8)))
            if len(changed.PixelData) % 2:
                changed.PixelData += b'\0'
            changed[0x7fe00010].VR = 'OB' if bits==8 else 'OW'
            add(f'sc-pixels-{bits}-{rows}-{cols}', 'valid', changed, iod=True)
    changed = base(); changed.PatientName = '合成^编码'; add('utf8-name', 'valid', changed, iod=True)
    for tag in EXPECT['required_type1'] + EXPECT['required_type2']:
        changed = base(); del changed[int(tag,16)]
        add('required-' + tag + '-missing', 'conditional', changed, blocked='MEDSEAL-E530',
            rule='required-type1' if tag in EXPECT['required_type1'] else 'required-type2', stage='requiredness')
    for tag in ['00080018','00080060','00280004']:
        changed=base(); changed[int(tag,16)].value=None
        add('required-'+tag+'-empty', 'conditional', changed, blocked='MEDSEAL-E530', rule='nonempty-type1', stage='requiredness')
    for tag in ['00080018','0020000D','0020000E']:
        changed=base(); changed[int(tag,16)].value='1.2.3\\1.2.4'
        add('vm-'+tag, 'malformed', changed, blocked='MEDSEAL-E530', rule='attr-'+tag, stage='vm')
    for i,value in enumerate(['A.B','1.02.3','1..2','1.2.'+'3'*61]):
        changed=base(); changed.SOPInstanceUID=value
        add('uid-invalid-'+str(i), 'malformed', changed, blocked='MEDSEAL-E530', rule='basic-values', stage='values')
    changed=base(); changed.SOPInstanceUID='1.2.'+'3'*60
    add('uid-64-boundary-valid','valid',changed)
    for date in ['20230229','19000229','20241301']:
        changed=base(); changed.StudyDate=date
        add('date-invalid-'+date, 'malformed', changed, blocked='MEDSEAL-E530', rule='basic-values', stage='values')
    temporal_policy = {'version': 2, 'mode': 'strict', 'namespace': 'temporal-qa',
                       'date_shift_days': 14, 'temporal_policy': 'retain-dt-precision-v1',
                       'path_rules': []}
    changed = base()
    changed.add_new(0x0008002A, 'DT', '20240229123456.123456')
    changed.add_new(0x00080201, 'SH', '+0800')
    add('temporal-precision-retained', 'valid', changed, config=temporal_policy,
        rules=['temporal-precision'])
    changed = base()
    changed.add_new(0x0008002A, 'DT', '202402')
    add('temporal-precision-low-cleared', 'privacy-risk', changed, config=temporal_policy,
        rules=['temporal-precision'])
    for n in [0,1,2,7,31,131,132,133]:
        add('header-cut-'+str(n), 'malformed', raw=encode(base())[:n], blocked='MEDSEAL-E101' if n<132 else 'MEDSEAL-E104')
    raw=encode(base())
    for tag in ['00020002','00020003']:
        altered=bytearray(raw)
        offset,start,length,_=element_span(raw,tag)
        altered[start+length-2] = ord('8')
        add('file-meta-identity-mismatch-'+tag,'malformed',raw=bytes(altered),blocked='MEDSEAL-E530',rule='file-meta-identity',stage='structure')
        offset,start,length,_=element_span(raw,tag)
        end=element_span(raw,'00080005')[0]
        altered=bytearray(raw[:end]+raw[offset:start+length]+raw[end:])
        _,group_length_start,_,_=element_span(raw,'00020000')
        struct.pack_into('<I',altered,group_length_start,struct.unpack_from('<I',raw,group_length_start)[0]+start+length-offset)
        add('file-meta-duplicate-'+tag,'malformed',raw=bytes(altered),blocked='MEDSEAL-E530',rule='unique-tags',stage='structure')
    for n in [1,2,3,4,5]:
        add('tail-cut-'+str(n), 'malformed', raw=raw[:-n], blocked='MEDSEAL-E203' if n<=4 else 'MEDSEAL-E201')
    offset,start,length,long=element_span(raw,'00100010')
    changed=bytearray(raw); changed[offset+4:offset+6]=b'ZZ'
    add('invalid-vr-name','malformed',raw=bytes(changed),blocked='MEDSEAL-E202')
    changed=bytearray(raw); changed[start:start+2]=b'\xc3('
    add('invalid-utf8','malformed',raw=bytes(changed),blocked='MEDSEAL-E109')
    for tag in ['00100010','00280010']:
        offset,start,length,_=element_span(raw,tag)
        add('duplicate-'+tag,'malformed',raw=raw+raw[offset:start+length],blocked='MEDSEAL-E530',rule='unique-tags',stage='structure')
    for tag in ['77760001','00080058','00181016']:
        changed=base(); changed.add_new(int(tag,16),'LO','SYNTHETIC-IDENTITY')
        add('unknown-'+tag,'privacy-risk',changed,blocked='MEDSEAL-E530',rule='known-public-attribute',stage='classification')
    for tag in ['00110010','00111010','60000010','04000010','FFFAFFFA','FFFCFFFC']:
        changed=base(); changed.add_new(int(tag,16),'LO','SYNTHETIC-IDENTITY')
        add('remove-structure-'+tag,'privacy-risk',changed,rules=['structure-remove'])
    for cs in ['ISO_IR 100','ISO 2022 IR 100']:
        changed=base(); changed.SpecificCharacterSet=cs
        add('charset-'+cs.replace(' ','-'),'unsupported',changed,blocked='MEDSEAL-E108')
    changed=base(); changed.SOPClassUID='1.2.840.10008.5.1.4.1.1.66.4'
    add('seg-sop','unsupported',changed,blocked='MEDSEAL-E530',rule='supported-sop',stage='profile')
    changed=base(); changed.file_meta.TransferSyntaxUID='1.2.840.10008.1.2'
    add('implicit-vr','unsupported',changed,blocked='MEDSEAL-E103')
    changed=base(); changed.DeidentificationMethod='SYNTHETIC PREVIOUS PASS'
    add('already-processed','unsupported',changed,blocked='MEDSEAL-E520')
    for tag,value,rule in [('00280102',6,'pixel-high-bit'),('00280002',3,'pixel-sample-bits')]:
        changed=base(); changed[int(tag,16)].value=value
        add('pixel-'+rule,'malformed',changed,blocked='MEDSEAL-E530',rule=rule,stage='pixels')
    changed=base(); changed.NumberOfFrames='2'
    add('multi-frame','unsupported',changed,blocked='MEDSEAL-E530',rule='pixel-single-frame',stage='pixels')
    changed=base(); changed.PixelData=b'\0\0'
    add('pixel-span-short','malformed',changed,blocked='MEDSEAL-E530',rule='pixel-length',stage='pixels')
    for tag, vr, text in [('00180050','DS','NaN '),('00200013','IS','1.25'),('00200013','IS','1e+2')]:
        changed=base(); changed.add_new(int(tag,16),vr,'9.99' if vr=='DS' else '9999')
        altered=bytearray(encode(changed)); _,start,length,_=element_span(altered,tag)
        assert length==4
        altered[start:start+length]=text.encode()
        add('numeric-invalid-'+vr+'-'+text.strip().replace('.','d').replace('+','p'),'malformed',raw=bytes(altered),blocked='MEDSEAL-E402')
    changed=base(); changed.ImagePositionPatient=['0','0']
    add('geometry-vm-invalid','malformed',changed,blocked='MEDSEAL-E530',rule='attr-00200032',stage='vm')
    changed=base(); changed.ReferencedImageSequence=Sequence([Dataset()])
    changed.ReferencedImageSequence[0].ReferencedSOPClassUID=SecondaryCaptureImageStorage
    add('reference-item-missing-instance','conditional',changed,blocked='MEDSEAL-E530',rule='required-type1',stage='requiredness')
    changed.ReferencedImageSequence[0].ReferencedSOPInstanceUID=changed.SOPInstanceUID
    changed.ReferencedImageSequence[0].PatientName='SYNTHETIC^FORBIDDEN'
    add('reference-item-identity-forbidden','privacy-risk',changed,blocked='MEDSEAL-E530',rule='reference-context',stage='context')
    cfg={'version':2,'mode':'strict','namespace':'qa','date_shift_days':30,'path_rules':[{'id':'specific','path':'dataset/00081030','action':'replace','value':'APPROVED','priority':2,'when_sop':str(SecondaryCaptureImageStorage),'when_present':'00280010'}]}
    add('policy-condition-met','conditional',base(),config=cfg,rules=['policy-priority'])
    changed_cfg=copy.deepcopy(cfg); changed_cfg['path_rules'][0]['when_sop']='1.2.840.10008.5.1.4.1.1.4'
    add('policy-condition-not-met','conditional',base(),config=changed_cfg,rules=['policy-priority'])
    changed_cfg=copy.deepcopy(cfg); changed_cfg['path_rules'][0]['when_present']='00180050'
    add('policy-presence-not-met','conditional',base(),config=changed_cfg,rules=['policy-priority'])
    changed=base(); del changed.SOPClassUID
    add('sop-condition-unknown-blocked','conditional',changed,blocked='MEDSEAL-E530',rule='required-type1',stage='requiredness')
    nested = struct.pack('<HH2sHI',0x0008,0x1140,b'SQ',0,0xffffffff)
    item = struct.pack('<HHI',0xfffe,0xe000,0xffffffff)
    close = struct.pack('<HHI',0xfffe,0xe00d,0)+struct.pack('<HHI',0xfffe,0xe0dd,0)
    prefix=raw[:element_span(raw,'00080005')[0]]
    add('sequence-undefined-missing-delimiter','malformed',raw=prefix+nested,blocked='MEDSEAL-E204')
    add('sequence-item-length-outside-parent','malformed',raw=prefix+struct.pack('<HH2sHI',0x0008,0x1140,b'SQ',0,8)+struct.pack('<HHI',0xfffe,0xe000,16),blocked='MEDSEAL-E204')
    add('sequence-delimiter-nonzero','malformed',raw=prefix+nested+struct.pack('<HHI',0xfffe,0xe0dd,2),blocked='MEDSEAL-E204')
    add('depth-33','resource-limit',raw=prefix+(nested+item)*33+close*33,blocked='MEDSEAL-E205')
    for length in [0x08000001,0xffffffff]:
        payload=struct.pack('<HH2sHI',0x0011,0x1010,b'OB',0,length)
        add('element-budget-'+str(length),'resource-limit',raw=prefix+payload,blocked='MEDSEAL-E203')
    item=struct.pack('<HH2sH',0x0011,0x1010,b'LO',0)
    add('element-count-100001','resource-limit',raw=prefix+item*100001,blocked='MEDSEAL-E207',recipe='element-count')
    # Independent closed-graph cases: source/owner/class conflict, not merely
    # conversion of a single object carrying an unchecked external reference.
    collections=[]
    for name in ['closed-reference','self-reference','unresolved-reference','cross-patient-reference','wrong-sop-class','duplicate-instance','cross-patient-study','cross-study-series','incompatible-uid-role']:
        a,b=base(),base()
        b.SOPInstanceUID='1.2.3.31'; b.InstanceNumber=2
        reference=Dataset(); reference.ReferencedSOPClassUID=SecondaryCaptureImageStorage
        reference.ReferencedSOPInstanceUID=b.SOPInstanceUID
        a.ReferencedImageSequence=Sequence([reference])
        members=[a,b]
        if name=='self-reference': reference.ReferencedSOPInstanceUID=a.SOPInstanceUID; members=[a]
        if name=='unresolved-reference': members=[a]
        if name=='cross-patient-reference': b.PatientID='SYNTHETIC-OTHER'; b.StudyInstanceUID='1.2.4.10'; b.SeriesInstanceUID='1.2.4.20'
        if name=='wrong-sop-class': reference.ReferencedSOPClassUID='1.2.840.10008.5.1.4.1.1.2'
        if name=='duplicate-instance': b.SOPInstanceUID=a.SOPInstanceUID
        if name=='cross-patient-study': b.PatientID='SYNTHETIC-OTHER'
        if name=='cross-study-series': b.StudyInstanceUID='1.2.4.10'
        if name=='incompatible-uid-role': b.SOPInstanceUID=a.StudyInstanceUID
        files=[]
        for index,ds in enumerate(members):
            filename='collection-'+name+'-'+str(index)+'.dcm'; data=encode(ds)
            fixtures[ROOT/'fixtures'/filename]=data
            files.append({'file':'fixtures/'+filename,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
        expected={'status':'passed','objects':len(members),'references':1,'external_references':0} if name in {'closed-reference','self-reference'} else {'status':'blocked','code':'MEDSEAL-E520'}
        collections.append({'id':name,'category':'conditional','members':files,'expected':expected,'required':True,'license':'Apache-2.0','source':'original synthetic; no patient data'})
    # Every required fixture is executed; there are no optional empty successes.
    entries.sort(key=lambda e:e['id'])
    manifest={'schema':1,'standard':'DICOM 2025e','fixture_license':'Apache-2.0','pydicom':'3.0.1',
              'expectations_sha256':hashlib.sha256((ROOT/'expectations.json').read_bytes()).hexdigest(),
              'official_dictionary_sha256':FACTS['dictionary_source_sha256'],
              'scope':'attribute VR/VM units plus synthetic strict pipeline; complete CT/MR profile not claimed',
              'entries':entries,'collections':collections}
    fixtures[ROOT/'manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    lines=['// Original synthetic corpus generated independently of MedSeal output.','///|','test "W1 fixed required corpus matches independently authored semantic expectations" {','  let mut executed = 0']
    for entry in entries:
        data=fixtures[ROOT/entry['file']]
        if entry['recipe']=='element-count':
            prefix=data[:-100001*8]
            literal='b"'+''.join('\\x%02x'%b for b in prefix)+'"'
            lines+=['  let writer = @byteio.ByteWriter::new()',f'  writer.write_bytes({literal})','  for _ in 0..<100001 { writer.write_bytes(b"\\x11\\x00\\x10\\x10LO\\x00\\x00") }','  let bytes = writer.to_bytes()']
        else:
            literal='b"'+''.join('\\x%02x'%b for b in data)+'"'
            lines.append('  let bytes = '+literal)
        lines+=['  // '+entry['id'],
                '  let actual = @lab.evaluate(bytes, '+json.dumps(entry['purpose'])+', tag='+json.dumps(entry['tag'])+', configuration='+json.dumps(entry['configuration'])+')',
                '  let expected = @json.parse('+json.dumps(canonical(entry['expected']),ensure_ascii=True)+')',
                '  assert_true(actual == expected, msg='+json.dumps(entry['id'])+')', '  executed = executed + 1']
    for collection in collections:
        literal=lambda data: 'b"'+''.join('\\x%02x'%b for b in data)+'"'
        inputs=', '.join(literal(fixtures[ROOT/m['file']]) for m in collection['members'])
        lines+=['  let actual = @lab.evaluate_collection(['+inputs+'])',
                '  let expected = @json.parse('+json.dumps(canonical(collection['expected']))+')',
                '  assert_true(actual == expected, msg='+json.dumps(collection['id'])+')','  executed = executed + 1']
    lines+=['  assert_eq(executed, '+str(len(entries)+len(collections))+')','}','']
    fixtures[ROOT/'lab/corpus_test.mbt']='\n'.join(lines).encode()
    return fixtures


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
    if pydicom.__version__!='3.0.1': raise RuntimeError('pydicom 3.0.1 required')
    with warnings.catch_warnings():
        warnings.simplefilter('ignore') # Intentional invalid values are corpus inputs.
        outputs=products()
    for path,data in outputs.items():
        if args.check:
            assert path.exists(), path
            if path.suffix=='.mbt':
                normalize=lambda s: semantic_tokens(s.decode())
                assert normalize(path.read_bytes())==normalize(data),path
            else:
                assert path.read_bytes()==data,path
        else:
            path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)
    print('Independent synthetic corpus generated/checked:',len(outputs)-2,'fixtures (including collection members)')


if __name__=='__main__': main()
