#ifndef SH_BRUTECRACKER_H
#define SH_BRUTECRACKER_H

#include "Cracker.h"

class BruteCracker : Cracker {
  public:
    void crack();

  private:
    void consume(unsigned long, unsigned long);
};

#endif // ndef SH_BRUTECRACKER_H
