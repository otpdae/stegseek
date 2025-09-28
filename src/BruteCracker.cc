#include "BruteCracker.h"
#include "Extractor.h"

// SIMD interleaving parameters
#define PASSPHRASES 4
#define ROW_MASK    3 // = PASSPHRASES - 1
#define ROW_SHIFT   2 // = log2(PASSPHRASES)
#define I(p, c)     (p << ROW_SHIFT) | ((c & ~ROW_MASK) << ROW_SHIFT) | (c & ROW_MASK)

extern "C" void computeSeeds(const unsigned char pp[64 * PASSPHRASES], unsigned int out[PASSPHRASES]);

void BruteCracker::crack() {
    auto alphabetSize = Args.BruteAlphabet.getValue().size();
    auto length = Args.BruteLength.getValue();
    auto threads = Args.Threads.getValue();

    auto total = 1UL;
    for (int i = 0; i < length; i++) {
        total *= alphabetSize;
    }

    auto part = total / threads + total % threads;
    std::vector<std::thread> threadPool;
    for (int i = 0; i < threads; i++) {
        threadPool.emplace_back(&BruteCracker::consume, this, i * part, (i + 1) * part);
    }
    for (int i = threads - 1; i >= 0; i--) {
        threadPool[i].join();
    }

    stopped = true;
    if (!success) {
        throw SteghideError("Could not find a valid passphrase.");
    }
    if (exception) {
        std::rethrow_exception(exception);
    }
}

void BruteCracker::consume(unsigned long i, unsigned long stop) {
    unsigned char dg[64 * PASSPHRASES] = {0};
    unsigned char pp[64 * PASSPHRASES] = {0};
    unsigned int out[PASSPHRASES] = {0};

    std::string alphabet = Args.BruteAlphabet.getValue();
    int alphabetSize = alphabet.size();
    char *ba = alphabet.data();
    int length = Args.BruteLength.getValue();
    int ppMax = length - 1;
    unsigned int seed = Args.BruteSeed.getValue();

    for (unsigned long initial = i, p = 0; p < PASSPHRASES; initial++, p++) {
        for (int m = 0; m < length; m++) {
            unsigned long weight = 1UL;
            for (int n = 0; n < m; n++) {
                weight *= alphabetSize;
            }
            int c = length - 1 - m;
            int n = I(p, c);
            int d = (initial / weight) % alphabetSize;
            dg[n] = d;
            pp[n] = ba[d];
        }
        pp[I(p, length)] = 0x80;    // MD5 "end of message" marker
        pp[I(p, 56)] = length << 3; // MD5 message length in bits
        pp[I(p, 57)] = length >> 5;
    }

    do {
        computeSeeds(pp, out);
        for (int p = 0; p < PASSPHRASES; p++) {
            if (out[p] == seed) {
                std::string passphrase(length, '\0');
                for (int c = 0; c < length; c++) {
                    passphrase[c] = pp[I(p, c)];
                }
                try {
                    Extractor ext(Args.StgFn.getValue(), passphrase);
                    EmbData *emb = ext.extract();
                    extract(emb);
                    delete emb;
                    success = true;
                    stopped = true;
                    printf("Found passphrase: \"%s\"\n", passphrase.c_str());
                    return;
                } catch (const SteghideError&) {}
            }
            for (int c = ppMax, inc = PASSPHRASES; c >= 0; c--, inc = 1) {
                int n = I(p, c);
                int d = dg[n] + inc;
                if (d < alphabetSize) {
                    dg[n] = d;
                    pp[n] = ba[d];
                    break;
                } else {
                    d -= alphabetSize;
                    dg[n] = d;
                    pp[n] = ba[d];
                }
            }
        }
        i += PASSPHRASES;
    } while (!stopped && i < stop);
}
