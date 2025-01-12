#define _DEFAULT_SOURCE          // see getnameinfo(3), for NI_MAX*
#define _POSIX_C_SOURCE 200112L  // see getaddrinfo(3)
#include <assert.h>
#include <limits.h>
#include <netdb.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

int resolve_addr(char *host, char *port, struct addrinfo **addrs) {
  struct addrinfo hints;
  memset(&hints, 0, sizeof(hints));

  hints.ai_socktype = SOCK_DGRAM;
  hints.ai_family = AF_UNSPEC;
  hints.ai_flags |= AI_NUMERICSERV;

  return getaddrinfo(host, port, &hints, addrs);
}

// Send given bytes[len] to the host:port via UDP, returns 1 if all bytes
// where sent and no locally detectable errors occurred.
int8_t send_to_flipdot(char *host, in_port_t port_number, uint8_t *bitmap,
                       size_t bitmap_len) {
  char port[NI_MAXSERV];
  int sockfd = -1;
  ssize_t sent = 0;
  struct addrinfo *addrs = NULL;

  if (snprintf(port, sizeof port, "%d", port_number) < 0) goto error;

  if (resolve_addr(host, port, &addrs) != 0) goto error;

  sockfd = socket(addrs->ai_family, SOCK_DGRAM, IPPROTO_UDP);
  if (sockfd < 0) goto error;

  sent =
      sendto(sockfd, bitmap, bitmap_len, 0, addrs->ai_addr, addrs->ai_addrlen);

  if (sent != (ssize_t)bitmap_len) goto error;

error:
  if (addrs != NULL) freeaddrinfo(addrs);
  if (sockfd >= 0) close(sockfd);
  return (sent == (ssize_t)bitmap_len);
}
