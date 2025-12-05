#include <stdio.h>
#include <stdlib.h>
#include "lua.h"
#include "lauxlib.h"
#include "aoi.h"

struct memstate {

	int count;
	int mem;
	int maxmem;
};

void *
myalloc(void *ud, void *ptr, size_t sz){

	struct memstate *state = (struct memstate *)ud;
	if(ptr == NULL){

		void *p = malloc(sz);
		state->count++;
		state->mem += sz;
		if(state->mem > state->maxmem){
			state->maxmem = state->mem;
		}
		return p;
	}
	--state->count;
	state->mem -= sz;
	free(ptr);
	return NULL;
}

static inline struct aoi_space * _get_aoi_space(lua_State *L){

	struct aoi_space **as = lua_touserdata(L, 1);
	if(as == NULL){
		luaL_error(L, "_get_aoi_space as is NULL.");
	}
	return *as;
}

static int _release(lua_State *L){

	struct aoi_space *as = _get_aoi_space(L);
	aoi_release(as);
	return 0;
}

static int _new(lua_State *L){

	struct memstate *state = malloc(sizeof(*state));
	state->count = 0;
	state->mem = 0;
	state->maxmem = 0;
	struct aoi_space *as = aoi_create(myalloc, state);//aoi_new();
	struct aoi_space **las = (struct aoi_space **)lua_newuserdata(L, sizeof(struct aoi_space *));
	*las = as;

	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);
	return 1;
}

static int 
lstate(lua_State *L){

	struct aoi_space *as = _get_aoi_space(L);
	struct memstate *state = as->alloc_ud;
	lua_pushinteger(L, state->count);
	lua_pushinteger(L, state->mem);
	lua_pushinteger(L, state->maxmem);
	return 3;
}

static int
laoi_update(lua_State *L){

	float poses[3];
	struct aoi_space *as = _get_aoi_space(L);
	uint32_t id = luaL_checknumber(L, 2);
	const char *mode = luaL_checkstring(L, 3);
	float x = luaL_checknumber(L, 4);
	float y = luaL_checknumber(L, 5);
	poses[0] = x;
	poses[1] = y;
	poses[2] = 0.0;
	aoi_update(as, id, mode, poses);
	return 0;
}

void
aoi_message_callback(void *ud, uint32_t watcher, uint32_t marker){

	struct lua_State *L = (struct lua_State *)ud;
	luaL_checktype(L, 2, LUA_TFUNCTION);
	lua_pushvalue(L, 2);
	lua_pushinteger(L, watcher);
	lua_pushinteger(L, marker);
	lua_call(L, 2, 0);
}

static int
laoi_message(lua_State *L){

	struct aoi_space *as = _get_aoi_space(L);
	aoi_message(as, aoi_message_callback, L);
	return 0;
}

int
luaopen_aoi_core(lua_State *L){

	luaL_checkversion(L);
	luaL_Reg l[] = {
		{"aoi_update", laoi_update},
		{"aoi_message", laoi_message},
		{"aoi_state", lstate},
		{"aoi_release", _release},
		{NULL, NULL}
	};

	// mt = {__index = l, __gc = delete}
	// newfunc(){ mt(upvalue) }
	lua_createtable(L, 0, 2);
	luaL_newlib(L, l);
	lua_setfield(L, -2, "__index");
	lua_pushcfunction(L, _release);
	lua_setfield(L, -2, "__gc");
	lua_pushcclosure(L, _new, 1);

	return 1;
}

