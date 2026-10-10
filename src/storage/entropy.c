#include <moonbit.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#endif

/* Only obtain operating-system entropy. No cryptographic algorithm is
 * implemented in this shim. Bytes are borrowed from the MoonBit caller. */
MOONBIT_FFI_EXPORT int medseal_entropy(moonbit_bytes_t output, int length) {
#ifdef _WIN32
  HMODULE lib = LoadLibraryA("advapi32.dll");
  if (!lib) return -1;
  typedef BOOLEAN (WINAPI *rng_fn)(PVOID, ULONG);
  rng_fn rng = (rng_fn)GetProcAddress(lib, "SystemFunction036");
  int result = rng && rng(output, (ULONG)length) ? 0 : -1;
  FreeLibrary(lib);
  return result;
#else
  int fd = open("/dev/urandom", O_RDONLY);
  if (fd < 0) return -1;
  int done = 0;
  while (done < length) {
    ssize_t count = read(fd, output + done, (size_t)(length - done));
    if (count < 0 && errno == EINTR) continue;
    if (count <= 0) { close(fd); return -1; }
    done += (int)count;
  }
  close(fd);
  return 0;
#endif
}
