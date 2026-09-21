# DECtalk for the talking Alpine stick: the ARM7/Epson single-threaded engine
# configuration (the same one the FreeDOS port uses), built with the container's
# musl gcc into libdectalk.a for rust-tdsr's `dectalk` feature, plus a small
# dtsay for tests. The engine source is fetched by run/get-dectalk.sh into
# src/upstream/dectalk (git-ignored; Fonix proprietary licence) and patched with
# patches/upstream.diff; files.txt lists the sources, glue/ the stubs.
#   make            libdectalk.a and dtsay (run inside the a11y-alpine-build container)
FD = .
UP = ../upstream/dectalk/src/dapi/src
SRCS = $(shell cat $(FD)/files.txt)
UPSRCS = $(addprefix $(UP)/,$(SRCS))
GLUE = $(FD)/glue/stubs.c
vpath %.c $(sort $(dir $(UPSRCS))) $(FD)/glue
OBJS = $(patsubst %.c,build/%.o,$(notdir $(SRCS) $(GLUE)))
DEFS = -DARM7 -DENGLISH_US -DACNA -DARM7_NOSWI -DENGLISH -Di386 -DWIN32_TEST -DBLD_DECTALK_DLL
INC = -I$(UP)/api -I$(UP)/cmd -I$(UP)/lts -I$(UP)/ph -I$(UP)/vtm -I$(UP)/kernel -I$(UP)/nt -I$(UP)/include -I$(UP)/../.. -I$(UP)/hlsyn -I$(FD)/glue
CFLAGS = -std=gnu11 -fpermissive -O2 -fno-strict-aliasing -fPIC -U__linux__ -U__linux -Ulinux -U__gnu_linux__ $(DEFS) $(INC) -w

all: libdectalk.a dtsay
libdectalk.a: $(OBJS)
	$(AR) rcs $@ $(OBJS)
dtsay: libdectalk.a $(FD)/glue/main_host.c
	$(CC) $(CFLAGS) -o $@ $(FD)/glue/main_host.c libdectalk.a -lm
build/%.o: %.c | build
	$(CC) $(CFLAGS) -c $< -o $@
build:
	mkdir -p $@
clean:
	rm -rf build libdectalk.a dtsay
.PHONY: all clean
