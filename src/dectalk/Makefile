# DECtalk for the talking Alpine stick: the ARM7/Epson single-threaded engine
# configuration (the same one the FreeDOS port uses), built with the container's
# musl gcc into libdectalk.a for rust-tdsr's `dectalk` feature, plus a small
# dtsay for tests. The engine source is fetched by run/get-dectalk.sh into
# src/upstream/dectalk (git-ignored; Fonix proprietary licence) and patched with
# patches/upstream.diff; files.txt lists the sources, glue/ the stubs.
#   make            out-$(ARCH)/libdectalk.a and out-$(ARCH)/dtsay (inside the build container;
#                   ARCH defaults to the container's apk architecture: x86_64 or x86)
ARCH ?= $(shell apk --print-arch 2>/dev/null || uname -m)
OUT = out-$(ARCH)
FD = .
UP = ../upstream/dectalk/src/dapi/src
SRCS = $(shell cat $(FD)/files.txt)
UPSRCS = $(addprefix $(UP)/,$(SRCS))
GLUE = $(FD)/glue/stubs.c
vpath %.c $(sort $(dir $(UPSRCS))) $(FD)/glue
OBJS = $(patsubst %.c,$(OUT)/obj/%.o,$(notdir $(SRCS) $(GLUE) maindict.c))
# CHEESY_DICT_COMPRESSION: the dictionary layout the ARM7 code reads (1-byte form class
# index per entry, as in Fonix's Epson project). Without it every lookup misreads the
# entries, function words fall through to the letter-to-sound rules and get stressed,
# and each word gets its own pitch accent.
DEFS = -DARM7 -DENGLISH_US -DACNA -DARM7_NOSWI -DENGLISH -Di386 -DWIN32_TEST -DBLD_DECTALK_DLL -DCHEESY_DICT_COMPRESSION
INC = -I$(UP)/api -I$(UP)/cmd -I$(UP)/lts -I$(UP)/ph -I$(UP)/vtm -I$(UP)/kernel -I$(UP)/nt -I$(UP)/include -I$(UP)/../.. -I$(UP)/hlsyn -I$(FD)/glue
CFLAGS = -std=gnu11 -fpermissive -O2 -fno-strict-aliasing -fPIC -U__linux__ -U__linux -Ulinux -U__gnu_linux__ $(DEFS) $(INC) -w

all: $(OUT)/libdectalk.a $(OUT)/dtsay
.DELETE_ON_ERROR:
# the objects follow the defines here (CHEESY_DICT_COMPRESSION must match the dictionary)
$(OBJS): $(FD)/Makefile
$(OUT)/libdectalk.a: $(OBJS)
	$(AR) rcs $@ $(OBJS)
$(OUT)/dtsay: $(OUT)/libdectalk.a $(FD)/glue/main_host.c
	$(CC) $(CFLAGS) -o $@ $(FD)/glue/main_host.c $(OUT)/libdectalk.a -lm
$(OUT)/obj/%.o: %.c | $(OUT)/obj
	$(CC) $(CFLAGS) -c $< -o $@
$(OUT)/obj:
	mkdir -p $@

# The main dictionary: the full US dictionary the Linux build uses (dic/Dic_us.txt compiled
# by upstream's dic.c), converted to the compressed layout above, instead of the 4809-word
# lts/maindict_us.c subset.
$(OUT)/gen/dic_us: $(UP)/dic/dic.c
	mkdir -p $(OUT)/gen
	$(CC) -O2 -w -DANSI -DENGLISH_US -DACCESS32 -DTYPING_MODE -DLTSSIM -DTTSSIM -I$(UP)/include -I$(UP)/api -I$(UP)/cmd -I$(UP)/dic -I$(UP)/kernel -I$(UP)/lts -I$(UP)/ph -I$(UP)/nt -I$(UP)/osf -I$(UP)/protos -I$(UP)/vtm -I$(UP)/../.. -o $@ $<
# (arguments starting with / are options to dic_us: keep the output name relative)
$(OUT)/gen/dtalk_us.dic: $(UP)/dic/Dic_us.txt $(OUT)/gen/dic_us
	cd $(OUT)/gen && ./dic_us $(abspath $<) dtalk_us.dic >/dev/null
$(OUT)/gen/maindict.c: $(OUT)/gen/dtalk_us.dic $(FD)/glue/dic2c.py
	python3 $(FD)/glue/dic2c.py $< $@
$(OUT)/obj/maindict.o: $(OUT)/gen/maindict.c | $(OUT)/obj
	$(CC) $(CFLAGS) -c $< -o $@
clean:
	rm -rf out-* build libdectalk.a dtsay
.PHONY: all clean
