#define LOG_LEVEL LOG_DEBUG

#include "process.h"

#include "kernel.h"

#include <abi.h>
#include <cpu.h>

#include <drivers/fileformat/elf.h>
#include <drivers/log.h>
#include <drivers/vfs.h>

#include <core/errno.h>
#include <core/inttypes.h>
#include <core/macros.h>
#include <core/path.h>
#include <core/sprintf.h>
#include <core/string.h>

#define PROCESS_MAX 8
static struct process pcb[PROCESS_MAX];
static pid_t          next_pid = 1;

struct process *process_alloc(void)
{
    for (int i = 0; i < PROCESS_MAX; i++)
        if (!pcb[i].pid) return &pcb[i];
    return NULL;
}

int process_load_path(struct process *p, const char *cwd, const char *path)
{
    int res, file_isopen = 0;

    /* Reset struct. */
    *p = (struct process){.pid = next_pid++};
    path_basename(p->name, DEBUGSTR_MAX, path);

    /* Open file. */
    res = file_open_path(&p->execfile, cwd, path);
    if (res < 0) goto error;
    file_isopen = 1;

    /* Read ELF header. */
    Elf32_Ehdr ehdr;
    res = elf_read_ehdr32(&p->execfile, &ehdr);
    if (res < 0) goto error;
    p->start_addr = ehdr.e_entry;

    /* Load segments. */
    for (int i = 0; i < ehdr.e_phnum; i++) {
        Elf32_Phdr phdr;
        res = elf_read_phdr32(&p->execfile, &ehdr, i, &phdr);
        if (res < 0) goto error;

        /* Skip non-load segments. */
        if (phdr.p_type != PT_LOAD) continue;

		/* Load. */
		elf_load_seg32(&p->execfile, &phdr);

    }

    return 0;
error:
    if (file_isopen) file_close(&p->execfile);
    return res;
}

void process_close(struct process *p)
{
    file_close(&p->execfile);
    *p = (struct process){};
}

typedef int main_fn(int argc, char *argv[]);

enum start_strategy {
    PSTART_CALL,
};

int process_start(struct process *p, int argc, char *argv[])
{
    enum start_strategy start_strat = PSTART_CALL;

    switch (start_strat) {
    case PSTART_CALL: {
        /* Start process via simple function call. */
		return ((main_fn*)p->start_addr)(argc, argv);

        return -ENOTSUP;
    }
    };

    return -ENOTSUP;
}

