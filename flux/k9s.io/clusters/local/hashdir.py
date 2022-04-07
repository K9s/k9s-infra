import os
from datetime import datetime
from glob import glob
from time import sleep
from checksumdir import dirhash

root_path = '../../..'

_last_hash = None
while True:
    _flux_hash = dirhash(f'{root_path}/k9s.io', include_paths=True)

    if _flux_hash != _last_hash:
        print(f'Hash {_flux_hash} @ {datetime.now().strftime("%b %-d %Y %-I:%M:%S %p")}')

    for f in glob(f'{root_path}/.hash-*'):
        os.remove(f)

    open(f'{root_path}/.hash-{_flux_hash}.txt', 'a')

    _last_hash = _flux_hash

    sleep(1)
