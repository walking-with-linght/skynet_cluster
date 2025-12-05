#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "skynet.h"

struct logger {
	FILE * handle;
	int close;
	int time;
};

struct logger *
logger_create(void) {
	struct logger * inst = skynet_malloc(sizeof(*inst));
	inst->handle = NULL;
	inst->close = 0;
	inst->time = -1;
	return inst;
}

void
logger_release(struct logger * inst) {
	if (inst->close) {
		fclose(inst->handle);
	}
	skynet_free(inst);
}

static void new_file(struct logger * inst,struct tm *t){

	if(!inst->close){
		return;
	}

	if(!t){
		unsigned int tmp = time(0);
		time_t tt = tmp;
		t = localtime(&tt);	
	}

	if(t->tm_hour != inst->time)
	{
		inst->time = t->tm_hour;
		char tmp[56] = "./log/";
		char filename[56] = {0};
		sprintf(filename, "%04d_%02d_%02d_%02d_game.log",1900+t->tm_year, 1 + t->tm_mon, t->tm_mday, 
			t->tm_hour);
		strcat(tmp, filename);
		if(inst->handle && inst->close){
			fclose(inst->handle);
		}
		inst->handle = fopen(tmp, "a+");
	}	
}

static int
_logger(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	
	struct logger * inst = ud;
	unsigned int tmp = time(0);
	time_t tt = tmp;
	struct tm *t = localtime(&tt);	
	new_file(inst, t);
	fprintf(inst->handle, "[:%08x][%04d-%02d-%02d %02d:%02d:%02d]",source,
		1900+t->tm_year, 1 + t->tm_mon, t->tm_mday, 
		t->tm_hour, t->tm_min, t->tm_sec);
	fwrite(msg, sz , 1, inst->handle);
	fprintf(inst->handle, "\n");
	fflush(inst->handle);

	return 0;
}

int
logger_init(struct logger * inst, struct skynet_context *ctx, const char * parm) {
	if (parm) {
		
		inst->close = 1;
		new_file(inst, NULL);
	} else {
		inst->handle = stdout;
	}
	if (inst->handle) {
		skynet_callback(ctx, inst, _logger);
		skynet_command(ctx, "REG", ".logger");
		return 0;
	}
	
	return 1;
}
