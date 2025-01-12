DESTDIR ?=
PREFIX ?= /usr
LIBDIR ?= $(DESTDIR)$(PREFIX)/lib
BINDIR ?= $(DESTDIR)$(PREFIX)/bin

CFLAGS ?= -Os
CFLAGS += -Wall -Wextra
LIBNAME = libflipdot.so

$(LIBNAME): flipdot.o
	$(CC) -shared -o $@ $^

.PHONY: clean fmt install
clean:
	rm -f *.o
	rm -f $(LIBNAME)

fmt:
	clang-format -style=google -i *.c

install: $(LIBNAME)
	install -Dm755 $(LIBNAME) -t $(LIBDIR)
	install -Dm644 blipqn.bqn -t $(LIBDIR)
	install -Dm755 examples.bqn $(BINDIR)/blipqn-examples
