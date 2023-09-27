var: var.y
	yacc var.y -o var.c
	gcc var.c -o var.o

postfix: postfix.y
	yacc postfix.y -o postfix.c
	gcc postfix.c -o postfix.o

expr_advanced: expr_advanced.y
	yacc expr_advanced.y -o expr_advanced.c
	gcc expr_advanced.c -o expr_advanced.o

expr: expr.y
	yacc expr.y -o expr.c
	gcc expr.c -o expr.o

.PHONY: clean all
clean:
	rm -rf *.o *.c

all:
	make postfix
	make expr_advanced
	make expr