#include <lua.h>
#include <lauxlib.h>
#include <sys/time.h>
#include <stdint.h>
#include <stdio.h>

static int
lgettime(lua_State *L){

	struct timeval val;
	if(gettimeofday(&val, NULL) < 0){
		luaL_error(L, "gettimeofday call failed.");
	}
	uint64_t t = val.tv_sec * 10000 + val.tv_usec / 100;
	lua_pushnumber(L, t);
	return 1;
}
/*
static int
laccurate4digits(lua_State *L){

	char *s = luaL_checkstring(L, 1);
	
}
*/
int 
luaopen_time(lua_State *L){

	luaL_checkversion(L);
	luaL_Reg l[] = {
		{"gettime", lgettime},
		{NULL, NULL}
	};
	luaL_newlib(L, l);
	return 1;
}
