%{
/*********************************************
将所有的词法分析功能均放在 yylex 函数内实现，为 +、-、*、\、(、 ) 每个运算符及整数分别定义一个单词类别，在 yylex 内实现代码，能
识别这些单词，并将单词类别返回给词法分析程序。
实现功能更强的词法分析程序，可识别并忽略空格、制表符、回车等
空白符，能识别多位十进制整数。
YACC file
**********************************************/
#include<stdio.h>
#include<stdlib.h>
#include<ctype.h>
#include<string.h>

int yylex();
extern int yyparse();
FILE* yyin;
void yyerror(const char* s);
%}

%union{
    double dval;
}
// 运算符类型
%token<dval> NUMBER
%token ADD MINUS
%token MULT DIV
%token QUIT

// 结合律与优先级
%left ADD MINUS
%left MULT DIV

// 开始符号与非终结符
%type<dval> expr
%start lines
%%


lines   :       lines expr ';'        {printf("\n");}
        |       lines ';'
        |       lines QUIT            { printf("Now exiting...\n");exit(0);}
        |       // 空串
        ;

expr    :       expr ADD expr               { printf(" + ");}
        |       expr MINUS expr             { printf(" - ");}
        |       expr MULT expr              { printf(" * ");}
        |       expr DIV expr               { printf(" / ");}
        |       NUMBER                      { printf(" %.2f ",$1);}
        ;

%%

// programs section

int yylex()
{
    int t;
    while(1){
        t=getchar();
        if(t==' '||t=='\t'||t=='\n'){
            // do noting
        }else if(isdigit(t)){
            double num = t - '0';
            t = getchar();

            while(isdigit(t)){  // 整数部分
                num = num*10 + t - '0';
                t = getchar();
            }

            if(t == '.'){       // 小数部分
                t = getchar();
                double w = 0.1;

                while(isdigit(t)){
                    num += (t - '0')*w;
                    w /= 10;
                    t = getchar();
                }

                yylval.dval = num; //通过yylval来设置返回值的属性
                ungetc(t,stdin);   //退回一格
                return NUMBER;
            }
            else{               // 没有小数
                yylval.dval = num;
                ungetc(t,stdin); //将多读的一个字符放回输入流
                return NUMBER;
            }

        }
        else if(t=='+'){
            return ADD;
        }
        else if(t=='-'){
            return MINUS;
        }
        else if(t == '*'){
            return MULT;
        }
        else if(t == '/'){
            return DIV;
        }
        else if(t == 'q'){
            return QUIT;
        }
        else{
            return t;
        }
    }
}

int main(void)
{
    yyin=stdin;
    do{
        yyparse();
    }while(!feof(yyin));
    return 0;
}
void yyerror(const char* s){
    fprintf(stderr,"Parse error: %s\n",s);
    exit(1);
}