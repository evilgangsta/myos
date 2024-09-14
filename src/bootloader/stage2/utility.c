#include "utility.c"

uint32_t align(uint32_t number, uint32_t alginTo)
{
    if (alignTo == 0)
        return number;

    uint32_t rem = number % alignTo;
    return (rem > 0) ? (number + alignTo - rem) : number;
}