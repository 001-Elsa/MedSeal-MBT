#!/usr/bin/env python3
"""Verify a pinned BSD mathematical phantom through real strict CT conversion."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile
import numpy
import pydicom
from PIL import Image
from verify_ct_research import make_series, read_series, REPO
from evidence import code_identity


def run(record):
    manifest = json.loads((REPO / 'resources/phantom/manifest.json').read_text())
    fixture = REPO / 'resources/phantom/shepp-logan.png'
    assert hashlib.sha256(fixture.read_bytes()).hexdigest() == manifest['sha256']
    pixels = numpy.asarray(Image.open(fixture).convert('L'), dtype=numpy.int16)
    # The external source is a mathematical intensity image, not calibrated HU.
    # Assign synthetic HU explicitly; no clinical or scanner claim is inferred.
    pixels = (pixels * 8).astype('<i2')
    with tempfile.TemporaryDirectory(prefix='medseal-phantom-') as folder:
        root = Path(folder)
        source = make_series(root, 8, (1,0,0,0,1,0), 1.0, count=3)
        for number, path in enumerate(sorted(source.glob('*.dcm'))):
            ds = pydicom.dcmread(path)
            ds.Rows, ds.Columns = pixels.shape
            ds.PixelData = (pixels + number).astype('<i2').tobytes()
            ds.RescaleIntercept = '-1024'; ds.RescaleSlope = '1'
            ds.save_as(path, enforce_file_format=True)
        output = root / 'converted'
        subprocess.run([str(REPO / '_build/native/debug/build/cmd/main/main.exe'), 'batch', str(source),
                        '--output', str(output), '--policy', str(REPO / 'examples/strict-policy.json')],
                       check=True, stdout=subprocess.DEVNULL)
        before, after = read_series(source), read_series(output)
        assert before['count'] == after['count'] == 3
        for left, right in zip(before['datasets'], after['datasets']):
            assert bytes(left.PixelData) == bytes(right.PixelData)
            assert numpy.array_equal(left.pixel_array, right.pixel_array)
            assert numpy.array_equal(left.pixel_array.astype('float64') - 1024, right.pixel_array.astype('float64') - 1024)
            assert tuple(left.ImagePositionPatient) == tuple(right.ImagePositionPatient)
    result = {'schema':1,'status':'passed','stage':'V4','source_kind':manifest['kind'],'source_sha256':manifest['sha256'],
              'slices':3,'rows':400,'columns':400,'pixel_differences':0,'hu_max_abs_error':0,
              'license':manifest['license'],'patient_data':False,'release_authorized':False,
              'limitations':['external mathematical pixels, locally generated synthetic DICOM',
                            'not external scanner/patient data, not calibrated clinical HU'],**code_identity(REPO)}
    record.parent.mkdir(parents=True,exist_ok=True)
    record.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record',type=Path,default=REPO/'tmp/v4-phantom-ci.json')
    run(parser.parse_args().record)
