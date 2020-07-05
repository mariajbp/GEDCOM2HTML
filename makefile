gedcom.exe : y.tab.o lex.yy.o 
	gcc -o gedcom.exe y.tab.o lex.yy.o   -ll `pkg-config --cflags --libs glib-2.0`

y.tab.o : y.tab.c
	gcc -c -g  y.tab.c  `pkg-config --cflags --libs glib-2.0`

lex.yy.o : lex.yy.c
	gcc -c -g lex.yy.c

y.tab.c y.tab.h y.output : gedcom.y 
	yacc -d -v --debug gedcom.y 

lex.yy.c : gedcom.l y.tab.h
	flex gedcom.l 

clean: assets gedcom.exe y.tab.o y.tab.c y.tab.h lex.yy.c y.output
	rm -rf assets gedcom.exe y.tab.o y.tab.c y.tab.h lex.yy.c y.output
reset: assets
	rm -rf assets
