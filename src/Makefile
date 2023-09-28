
objects = codeTrans var postfix expr_advanced expr 

codeTrans: codeTrans.y
	yacc codeTrans.y -o codeTrans.c
	gcc codeTrans.c -o codeTrans

var: var.y
	yacc var.y -o var.c
	gcc var.c -o var

postfix: postfix.y
	yacc postfix.y -o postfix.c
	gcc postfix.c -o postfix

expr_advanced: expr_advanced.y
	yacc expr_advanced.y -o expr_advanced.c
	gcc expr_advanced.c -o expr_advanced

expr: expr.y
	yacc expr.y -o expr.c
	gcc expr.c -o expr

.PHONY: clean all
clean:
	rm -rf *.o *.c

all:
<<<<<<< HEAD
	make $(objects)
=======
	make postfix
	make expr_advanced
	make expr
	make var
>>>>>>> 9885d8e0f9c7781bcad5055a21b4fcdc6d18a21c
