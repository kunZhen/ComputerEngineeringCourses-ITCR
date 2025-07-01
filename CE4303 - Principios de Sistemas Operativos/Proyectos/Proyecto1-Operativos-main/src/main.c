#include <stdio.h>

#include "scheduler/scheduler.h"
#include "street/street.h"
#include "lib/CEthreads.h"

int main() {
  printf("Welcome to Scheduling Cars! 🚗 🏎️ 🚨\n");
  street_tryout();
  return 0;
}