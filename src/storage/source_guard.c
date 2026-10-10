#include <moonbit.h>
#include <stdlib.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <sys/stat.h>
#include <unistd.h>
#endif

/* A narrow OS adapter. No DICOM or cryptographic logic lives here. */
MOONBIT_FFI_EXPORT int medseal_source_guard(int fd, moonbit_bytes_t path) {
#ifdef _WIN32
  (void)fd;
  int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (char *)path, -1, NULL, 0);
  if (!size) return -1;
  wchar_t *wide = (wchar_t *)malloc((size_t)size * sizeof(wchar_t));
  if (!wide) return -1;
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (char *)path, -1, wide, size);
  HANDLE h = CreateFileW(wide, FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
      FILE_FLAG_OPEN_REPARSE_POINT, NULL);
  free(wide);
  if (h == INVALID_HANDLE_VALUE) return -1;
  BY_HANDLE_FILE_INFORMATION info;
  int ok = GetFileInformationByHandle(h, &info);
  CloseHandle(h);
  if (!ok) return -1;
  if (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) return -2;
  return info.nNumberOfLinks == 1 ? 0 : -2;
#else
  struct stat opened, named;
  if (fstat(fd, &opened) != 0 || lstat((char *)path, &named) != 0) return -1;
  if (!S_ISREG(opened.st_mode) || !S_ISREG(named.st_mode) || opened.st_nlink != 1) return -2;
  if (opened.st_dev != named.st_dev || opened.st_ino != named.st_ino) return -3;
  return 0;
#endif
}
