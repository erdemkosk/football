"""Read only the Windows release entry from the official template ZIP via HTTPS ranges."""
import io
from pathlib import Path
import tempfile
import urllib.request
import zipfile

URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
class RemoteZip(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL, method='HEAD')) as response:
            self.url = response.url
            self.size = int(response.headers['Content-Length'])
        self.position = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else (self.position + offset if whence == 1 else self.size + offset)
        return self.position
    def read(self, count=-1):
        count = self.size - self.position if count < 0 else min(count, self.size - self.position)
        if count <= 0: return b''
        request = urllib.request.Request(self.url, headers={'Range': f'bytes={self.position}-{self.position + count - 1}'})
        with urllib.request.urlopen(request) as response:
            if response.status != 206:
                raise RuntimeError('Server did not honor range request')
            result = response.read()
        if len(result) != count: raise RuntimeError('Incomplete ranged response')
        self.position += len(result)
        return result

destination = Path(tempfile.gettempdir()) / 'sefc-native-tools/windows_release_x86_64.exe'
with zipfile.ZipFile(RemoteZip()) as archive:
    matches = [info for info in archive.infolist() if info.filename == 'templates/windows_release_x86_64.exe']
    if len(matches) != 1: raise RuntimeError('Expected one Windows release template')
    data = archive.read(matches[0])  # ZipFile also validates the entry CRC.
destination.parent.mkdir(exist_ok=True)
destination.write_bytes(data)
print(destination, 'bytes=', len(data))
