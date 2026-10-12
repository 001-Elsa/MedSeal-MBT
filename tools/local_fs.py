"""Controlled local POSIX filesystem primitives; no network-FS certification."""
from pathlib import Path
import ctypes
import errno
import hashlib
import os
import stat
import sys
from private_store import StoreError, sync_directory, write_exclusive


def digest(path):
    path = Path(path)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
            raise StoreError('unsafe-source-file')
        value = hashlib.sha256()
        while True:
            data = os.read(fd, 1024 * 1024)
            if not data:
                break
            value.update(data)
        after = os.fstat(fd)
        current = path.lstat()
        if signature(before) != signature(after) or (after.st_dev, after.st_ino) != (current.st_dev, current.st_ino):
            raise StoreError('source-changed')
        return value.hexdigest()
    finally:
        os.close(fd)


def signature(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns, info.st_nlink)


def rename_new(source, destination):
    source, destination = Path(source), Path(destination)
    library = ctypes.CDLL(None, use_errno=True)
    if sys.platform == 'darwin':
        operation = library.renamex_np
        operation.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        result = operation(os.fsencode(source), os.fsencode(destination), 4)
    elif sys.platform.startswith('linux') and hasattr(library, 'renameat2'):
        operation = library.renameat2
        operation.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        result = operation(-100, os.fsencode(source), -100, os.fsencode(destination), 1)
    else:
        raise StoreError('no-replace-publication-platform-unsupported')
    if result:
        raise OSError(ctypes.get_errno(), 'no-replace-publication-failed')
    sync_directory(destination.parent)
    if source.parent != destination.parent:
        sync_directory(source.parent)


def atomic_private(path, data):
    import secrets
    path = Path(path)
    temporary = path.parent / ('.pending-' + secrets.token_hex(16))
    write_exclusive(temporary, data)
    os.replace(temporary, path)
    sync_directory(path.parent)


def copy_file_new(source, destination, expected, maximum=256 * 1024 * 1024):
    source, destination = Path(source), Path(destination)
    input_fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(input_fd)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1 or before.st_size > maximum:
            raise StoreError('copy-source-invalid-or-over-budget')
        output_fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        try:
            checksum = hashlib.sha256()
            while True:
                data = os.read(input_fd, 1024 * 1024)
                if not data:
                    break
                checksum.update(data)
                view = memoryview(data)
                while view:
                    count = os.write(output_fd, view)
                    if not count:
                        raise StoreError('short-delivery-write')
                    view = view[count:]
            if checksum.hexdigest() != expected or signature(os.fstat(input_fd)) != signature(before) or signature(source.lstat()) != signature(before):
                raise StoreError('delivery-source-changed')
            os.fsync(output_fd)
        finally:
            os.close(output_fd)
    finally:
        os.close(input_fd)
    sync_directory(destination.parent)
