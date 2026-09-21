/* dtsay: DECtalk (ARM7 single-threaded configuration) on the host, text -> 16-bit WAV.
 *   dtsay [-r 8000|11025] [-o out.wav] [-q] text...        (default 11025 Hz, out.wav)
 * Prints synthesis time so the engine cost can be compared with the DOS builds. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "epsonapi.h"

static short blk[71];
static FILE *out;
static long nsamp;
static int blksize = 71;
static long abort_after = -1, nblocks;      /* -a N: return NULL from the callback after N blocks (a flush) */

static short *cb(short *b, long code)
{
    if (code == 3) return b;              /* index mark: keep going */
    if (abort_after >= 0 && nblocks++ >= abort_after) return NULL;
    fwrite(b, 2, blksize, out);
    nsamp += blksize;
    return b;
}
static void put32(FILE *f, unsigned v) { unsigned char b[4] = { v, v >> 8, v >> 16, v >> 24 }; fwrite(b, 1, 4, f); }
static void put16(FILE *f, unsigned v) { unsigned char b[2] = { v, v >> 8 }; fwrite(b, 1, 2, f); }

int main(int argc, char **argv)
{
    int rate = 11025, quiet = 0, i, fmt, multi = 0;
    const char *outname = "out.wav";
    char text[4096] = "";
    clock_t t0, t1;
    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-r") && i + 1 < argc) rate = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-o") && i + 1 < argc) outname = argv[++i];
        else if (!strcmp(argv[i], "-q")) quiet = 1;
        else if (!strcmp(argv[i], "-a") && i + 1 < argc) abort_after = atol(argv[++i]);
        else if (!strcmp(argv[i], "-m")) multi = 1;
        else { if (*text) strcat(text, " "); strncat(text, argv[i], sizeof text - strlen(text) - 2); }
    }
    if (!*text) { fprintf(stderr, "usage: dtsay [-r 8000|11025] [-o out.wav] text...\n"); return 2; }
    fmt = rate == 8000 ? WAVE_FORMAT_08M16 : WAVE_FORMAT_1M16;
    blksize = rate == 8000 ? 51 : 71;
    if (rate != 8000) rate = 11025;
    out = fopen(outname, "wb");
    if (!out) { perror(outname); return 1; }
    fseek(out, 44, SEEK_SET);
    t0 = clock();
    if (TextToSpeechInit(cb, NULL) != ERR_NOERROR) { fprintf(stderr, "init failed\n"); return 1; }
    t1 = clock();
    if (multi) {                          /* -m: then read more utterances from stdin, one per line, like the resident does */
        char line[600]; int r, n = 0;
        r = TextToSpeechStart(text, blk, fmt); fprintf(stderr, "utt 0 -> %d\n", r);
        while (fgets(line, sizeof line, stdin)) {
            line[strcspn(line, "\r\n")] = 0; nblocks = 0;
            r = TextToSpeechStart(line, blk, fmt); fprintf(stderr, "utt %d -> %d (%ld samples so far)\n", ++n, r, nsamp);
        }
    } else
    if (TextToSpeechStart(text, blk, fmt) != ERR_NOERROR) fprintf(stderr, "start returned early\n");
    {
        clock_t t2 = clock();
        double audio = (double)nsamp / rate, synth = (double)(t2 - t1) / CLOCKS_PER_SEC;
        if (!quiet)
            fprintf(stderr, "init %.3f s, synth %.3f s for %.2f s of audio (%.1fx real time), %ld samples\n",
                    (double)(t1 - t0) / CLOCKS_PER_SEC, synth, audio, synth > 0 ? audio / synth : 0, nsamp);
    }
    fseek(out, 0, SEEK_SET);
    fwrite("RIFF", 1, 4, out); put32(out, 36 + nsamp * 2); fwrite("WAVEfmt ", 1, 8, out);
    put32(out, 16); put16(out, 1); put16(out, 1); put32(out, rate); put32(out, rate * 2); put16(out, 2); put16(out, 16);
    fwrite("data", 1, 4, out); put32(out, nsamp * 2);
    fclose(out);
    return 0;
}
