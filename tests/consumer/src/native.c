#include <impeller.h>
#include <stdio.h>

int main(void) {
    ImpellerPaint paint = ImpellerPaintNew();
    if (paint == NULL) {
        return 1;
    }
    ImpellerPaintRelease(paint);

    printf("native ok: version=%d\n", (int)IMPELLER_VERSION);
    return 0;
}
