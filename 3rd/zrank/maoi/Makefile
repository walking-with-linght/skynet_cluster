all:aoi.so

CC = gcc
CFLAG = -g3 -O0 -Wall -fPIC --shared
LUA_INCLUDE_DIR = /usr/local/include

aoi.so:aoi.h aoi.c lua-aoi.c
	$(CC) $(CFLAG)  $^ -o $@

test:
	lua aoi.lua

clean:
	rm -f aoi.so	
