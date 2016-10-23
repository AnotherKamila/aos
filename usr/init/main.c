/**
 * \file
 * \brief init process for child spawning
 */

/*
 * Copyright (c) 2007, 2008, 2009, 2010, 2016, ETH Zurich.
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached LICENSE file.
 * If you do not find this file, copies can be found by writing to:
 * ETH Zurich D-INFK, Haldeneggsteig 4, CH-8092 Zurich. Attn: Systems Group.
 */

#include <stdio.h>
#include <stdlib.h>

#include <aos/aos.h>
#include <aos/waitset.h>
#include <aos/morecore.h>
#include <aos/paging.h>

#include <mm/mm.h>
#include "mem_alloc.h"

coreid_t my_core_id;
struct bootinfo *bi;

int main(int argc, char *argv[])
{
    errval_t err;

    /* Set the core id in the disp_priv struct */
    err = invoke_kernel_get_core_id(cap_kernel, &my_core_id);
    assert(err_is_ok(err));
    disp_set_core_id(my_core_id);

    debug_printf("init: on core %" PRIuCOREID " invoked as:", my_core_id);
    for (int i = 0; i < argc; i++) {
       printf(" %s", argv[i]);
    }
    printf("\n");

    /* First argument contains the bootinfo location, if it's not set */
    bi = (struct bootinfo*)strtol(argv[1], NULL, 10);
    if (!bi) {
        assert(my_core_id > 0);
    }

    CHECK("slot_alloc_init", slot_alloc_init());

    err = initialize_ram_alloc();
    if(err_is_fail(err)){
        DEBUG_ERR(err, "initialize_ram_alloc");
    }

    struct capref frame[20];
    for (int i = 0; i < 20; ++i) slot_alloc(&frame[i]);
    size_t retsize[20];
    for (int i = 0; i < 20; ++i) {
        CHECK("allocating frame",
              frame_alloc(&frame[i], 50000000, &retsize[i]));
        // struct frame_identity frame_id;
        // CHECK("identifying frame",
        //       frame_identify(frame[i], &frame_id));
        // *((char*)(frame_id.base)) = 47;
    }
    for (int i = 0; i < 10; ++i) {
        CHECK("freeing frame",
              aos_ram_free(frame[i], retsize[i]));
    }
    for (int i = 0; i < 10; ++i) {
        CHECK("allocating frame",
              frame_alloc(&frame[i], 50000000, &retsize[i]));
    }
    for (int i = 0; i < 20; ++i) {
        CHECK("freeing frame",
              aos_ram_free(frame[i], retsize[i]));
    }

    debug_printf("Message handler loop\n");
    // Hang around
    struct waitset *default_ws = get_default_waitset();
    while (true) {
        err = event_dispatch(default_ws);
        if (err_is_fail(err)) {
            DEBUG_ERR(err, "in event_dispatch");
            abort();
        }
    }

    return EXIT_SUCCESS;
}
