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

//实现符号表
#define VAR_TABLE_LEN 20
#define VAR_NAME_LEN 30

char    var_name_table[VAR_TABLE_LEN][VAR_NAME_LEN] = {};
double  var_value_table [VAR_TABLE_LEN] = {};
int     var_num = 0;
%}

%union{
    double dval;
    char* chval;
}
// 运算符类型
%token<dval> NUMBER
%token ADD MINUS
%token MULT DIV
%token L_BRAC R_BRAC
%token QUIT

%token<chval> VARNAME 
%token ASSIGN
// 结合律与优先级
%left ADD MINUS
%left MULT DIV
%right UMINUS

// 开始符号与非终结符
%type<dval> expr
%type<dval> stmt
%start lines
%%


lines   :       lines stmt ';' { printf("\t\t VALUE = %f\n", $2); }
        |       lines ';'
        |       lines QUIT            { printf("Now exiting...\n");exit(0);}
        |       // 空串
        ;

stmt    :       VARNAME ASSIGN expr         { if(var_num == VAR_TABLE_LEN)
                                                { printf("Too many varables, exiting...\n");exit(0);}
                                              strcpy(var_name_table[var_num], $1);
                                              var_value_table[var_num] = $3;
                                              $$ = $3; var_num ++;}
        |       expr                        { $$ = $1;}
        ;

expr    :       expr ADD expr               { $$=$1+$3;}
        |       expr MINUS expr             { $$=$1-$3;}
        |       expr MULT expr              { $$=$1*$3;}
        |       expr DIV expr               { $$=$1/$3;}
        |       MINUS expr   %prec UMINUS   { $$=-$2;}//重新指定优先级，因为这里使用的是MINUS，要将优先级改为 UMINUS
        |       NUMBER                      { $$=$1;}
        |       L_BRAC expr R_BRAC          { $$=$2;}
        |       VARNAME                     { for(int i=0;i<var_num;i++) 
                                                {
                                                    if(strcmp(var_name_table[i],$1)==0)
                                                    {
                                                        $$ = var_value_table[i];
                                                        break;
                                                    }
                                                }
        
                                            }
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

                yylval.dval = num;
                ungetc(t,stdin);
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
        else if(t == '('){
            return L_BRAC;
        }
        else if(t == ')'){
            return R_BRAC;
        }
        else if(t == '='){
            return ASSIGN;
        }
        else if(t == 'q'){
            return QUIT;
        }
        else if(isalpha(t)){
            char* tmp = malloc(VAR_NAME_LEN);
            tmp[0] = t;
            t = getchar();
            while(isalpha(t)){
                strcat(tmp,(char*)&t);
                t = getchar();
            }
            ungetc(t,stdin);
            yylval.chval = tmp;
            return VARNAME;
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