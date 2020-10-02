#include <time.h>
#include <stdio.h>
#define NUMTEST 100000

#define WIDTH 4

typedef unsigned char uint8_t;
typedef unsigned int uint16_t;

static uint16_t ch2hex(char ch) {
  switch (ch) {
  case '0' ... '9':
    return ch - '0';
  case 'a' ... 'f':
    return ch - 'a' + 10;
  case 'A' ... 'F':
    return ch - 'A' + 10;
  }
}

static uint16_t log2(uint16_t a) {
  uint16_t l = 0;
  while (a >>= 1) {
    ++l;
  }
  return l;
}

static uint8_t dist[8 * WIDTH];

int main(int argc, char **argv) {
  struct timespec start,end;
  clock_gettime(CLOCK_REALTIME, &start); 

  for(int try = 0; try<NUMTEST; try++){
  uint8_t g8[WIDTH], e8[WIDTH];

  // Read input from argv
  for (int i = 0; i < WIDTH; i++)
    g8[i] = ch2hex(argv[i + 1][0]) * 16 + ch2hex(argv[i + 1][1]);
  for (int i = 0; i < WIDTH; i++)
    e8[i] =
        ch2hex(argv[i + WIDTH + 1][0]) * 16 + ch2hex(argv[i + WIDTH + 1][1]);

  // Calculate
  for (uint16_t i = 0; i < WIDTH; i++) {
    for (uint16_t j = 0; j < 8; j++) {
      dist[i * 8 + j] = ((g8[i] ^ e8[i]) & (1 << j)) >> (j);
    }
  }

  int l = (int)log2(8 * WIDTH);

  for (int j = l - 1; j >= 0; j--) {
    for (uint16_t i = 0; i < (uint16_t)(1 << j); i++) {
      dist[i] = dist[2 * i] + dist[2 * i + 1];
    }
  }
  }
  clock_gettime(CLOCK_REALTIME, &end); 
  printf("%ld\n",(end.tv_nsec-start.tv_nsec)/NUMTEST);
  return dist[0];
}
