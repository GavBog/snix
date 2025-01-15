#define _DEFAULT_SOURCE          // see getnameinfo(3), for NI_MAX*
#define _POSIX_C_SOURCE 200112L  // see getaddrinfo(3)
#include <assert.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
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

struct flipdot {
  int sockfd;
  struct addrinfo *addrs;
};

// Assumes all pointers in struct flipdot are not NULL which should be the case
// for any struct returned by flipdot_open().
void flipdot_close(struct flipdot *flipdot) {
  freeaddrinfo(flipdot->addrs);
  close(flipdot->sockfd);
  free(flipdot);
}

// Returns NULL if some error occurred. Note that errno isn't necessarily set.
struct flipdot *flipdot_open(char *host, in_port_t port_number) {
  char port[NI_MAXSERV];
  struct flipdot *flipdot = malloc(sizeof(struct flipdot));
  if (flipdot == NULL) goto error;

  memset(flipdot, 0, sizeof(struct flipdot));
  flipdot->sockfd = -1;
  flipdot->addrs = NULL;

  if (snprintf(port, sizeof(port), "%d", port_number) < 0) goto error;
  if (resolve_addr(host, port, &flipdot->addrs) != 0) goto error;

  flipdot->sockfd = socket(flipdot->addrs->ai_family, SOCK_DGRAM, IPPROTO_UDP);
  if (flipdot->sockfd < 0) goto error;

  return flipdot;

error:
  if (flipdot != NULL) {
    if (flipdot->sockfd >= 0) close(flipdot->sockfd);
    if (flipdot->addrs != NULL) freeaddrinfo(flipdot->addrs);
    free(flipdot);
  }

  return NULL;
}

// Send given bytes[len] to the given flipdot, returns 1 if all bytes were sent
// and no locally detectable errors occurred, 0 otherwise.
int8_t flipdot_send(struct flipdot *flipdot, uint8_t *bitmap,
                    size_t bitmap_len) {
  ssize_t sent = sendto(flipdot->sockfd, bitmap, bitmap_len, 0,
                        flipdot->addrs->ai_addr, flipdot->addrs->ai_addrlen);

  return (sent == (ssize_t)bitmap_len);
}
