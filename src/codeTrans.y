%{
#include<stdio.h>
#include<stdlib.h>
#include<ctype.h>
#include<string.h>
#include<stdbool.h>

int yylex();
extern int yyparse();
FILE* yyin;
void yyerror(const char* s);

//寄存器分配
int reg_alloc();
//寄存器释放
void reg_free(int reg);
//打印俩寄存器
void print_reg(int reg1, int reg2);

//寄存器
#define REG_NUM 14

//实现符号表
#define VAR_TABLE_LEN 6
#define VAR_NAME_LEN 30

char    var_name_table[VAR_TABLE_LEN][VAR_NAME_LEN] = {};   //符号表
double  var_value_table [VAR_TABLE_LEN] = {};   //符号值表
int     var_num = 0;    //当前符号表中的变量个数
char*   reg_name_table[] = {"%rax","%rbx","%rcx","%rdx","%rsi", 
                        "%rdi","%r8","%r9","%r10","%r11",
                        "%r12","%r13","%r14","%r15"};//寄存器表,共14个
bool    reg_used_table[14] = {false};//寄存器使用表
struct  expr{
    int ival;
    int regNo;
};

%}

%union{
    struct expr exprval ;
    int ival;
    char* chval;
}
// 运算符类型
%token<ival> NUMBER
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
%type<exprval> expr
%type<ival> stmt
%start lines
%%


lines   :       lines stmt ';' { printf("\t\t VALUE = %d\n", $2); }
        |       lines ';'
        |       lines QUIT            { printf("Now exiting...\n");exit(0);}
        |       // 空串
        ;

stmt    :       VARNAME ASSIGN expr         { if(var_num == VAR_TABLE_LEN)
                                                { printf("Too many varables, exiting...\n");exit(0);}
                                              strcpy(var_name_table[var_num], $1);
                                              var_value_table[var_num] = $3.ival;
                                              $$ = $3.ival; var_num ++;}
        |       expr                        { $$ = $1.ival;reg_free($1.regNo);}
        ;

expr    :       expr ADD expr               { $$.ival=$1.ival+$3.ival;printf("\tadd"); print_reg($1.regNo, $3.regNo);reg_free($3.regNo);}
        |       expr MINUS expr             { $$.ival=$1.ival-$3.ival;printf("\tsub"); print_reg($1.regNo, $3.regNo);reg_free($3.regNo);}
        |       expr MULT expr              { $$.ival=$1.ival*$3.ival;printf("\tmul"); print_reg($1.regNo, $3.regNo);reg_free($3.regNo);}//假设可以使用乘法指令
        |       expr DIV expr               { $$.ival=$1.ival/$3.ival;printf("\tdiv"); print_reg($1.regNo, $3.regNo);reg_free($3.regNo);}//假设可以使用除法指令
        |       MINUS expr   %prec UMINUS   { $$.ival=-$2.ival;}//重新指定优先级，因为这里使用的是MINUS，要将优先级改为 UMINUS
        |       NUMBER                      { $$.ival=$1; $$.regNo = reg_alloc(); printf("\tmov %s, %d\n", reg_name_table[$$.regNo],$1);}
        |       L_BRAC expr R_BRAC          { $$.ival=$2.ival;}
        |       VARNAME                     { for(int i=0;i<var_num;i++) 
                                                {
                                                    if(strcmp(var_name_table[i],$1)==0)
                                                    {
                                                        $$.ival = var_value_table[i];
                                                        break;
                                                    }
                                                }
                                            }
        ;

%%
//寄存器分配
int reg_alloc(){
    for(int i=0;i<14;i++){
        if(!reg_used_table[i]){
            reg_used_table[i] = true;
            return i;
        }
    }
    printf("No more registers available, exiting...\n");
    exit(0);
}

//寄存器释放
void reg_free(int reg){
    reg_used_table[reg] = false;
}

//打印俩寄存器
void print_reg(int reg1, int reg2){
    printf(" %s, %s\n",reg_name_table[reg1],reg_name_table[reg2]);
}

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
            yylval.ival = num;
            ungetc(t,stdin); //将多读的一个字符放回输入流
            return NUMBER;
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