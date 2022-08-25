#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdlib.h>

MODULE = Shadow::RSS::RSSSX  PACKAGE = Shadow::RSS::RSSSX
PROTOTYPES: ENABLE

unsigned int
rand()
